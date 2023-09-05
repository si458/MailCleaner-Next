#!/usr/bin/perl -U -I /usr/share/MailScanner/perl
#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: mailscanner.sbin 5102 2011-08-20 12:31:59Z sysjkf $
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#      https://www.mailscanner.info
#
# 	Updated: 	MailScanner Team <https://www.mailscanner.info>
#             19 January 2020

use strict;
no strict 'subs';
use POSIX;
require 5.005;

# chdir to a known good working directory
# Avoids permissions issues with current working directory
chdir('/usr/share/MailScanner/perl');

# Awkard BEGIN block so that we pick up MIME::Base64 from the right place!
BEGIN {
  my(@oldinc,@safecopy,$path,@corepaths,@notcorepaths);

  my $seensv = 0;
  foreach $path (@INC) {
    if ($path =~ /site|vendor/i) {
      $seensv = 1;
    }
    if ($seensv) {
      push @notcorepaths, $path unless $path eq '.';
      next;
    }
    # If it's a simple path before site or vendor, save it for the end
    if ($path =~ m#/usr/(local/)?lib\d*/perl\d*/\d\.\d#) {
      push @corepaths, $path;
    } else {
      push @notcorepaths, $path;
    }
  }

  # Now we have all the site and vendor paths in @notcorepaths, and the
  # perl5 paths in @corepaths. We want notcore + core, so the notcore ones
  # take priority.
  #print STDERR '@INC = ' . "\n" . join("\n", @INC) . "\n";
  @INC = (@notcorepaths, @corepaths);
  #print STDERR '@INC = ' . "\n" . join("\n", @INC) . "\n";

  # Look in /usr/local/MailScanner/utils for the modules
  @oldinc = @INC;
  @safecopy = @INC;

  # Duplicate path with /usr/local/MailScanner/utils stuck on the front
  # of each element
  foreach $path (reverse @oldinc) {
    next unless $path =~ /\//;
    $path =~ s/^\/usr/\/share\/MailScanner\/perl/;
    unshift @INC, $path;
  }

  require MIME::Base64;
  require MIME::QuotedPrint;

  @INC = @safecopy;
}

use FileHandle;
use File::Path;
use IO::Handle;
use IO::File;
use Getopt::Long;
use Time::HiRes qw ( time );
use Filesys::Df;
use IO::Stringy;
use Sys::Hostname::Long;
use DBI;
use MailScanner::Antiword;
use MailScanner::Config;
use MailScanner::CustomConfig;
use MailScanner::GenericSpam;
#use MailScanner::LinksDump;
use MailScanner::Lock;
use MailScanner::Log;
use MailScanner::Mail;
use MailScanner::MessageBatch;
use MailScanner::Quarantine;
use MailScanner::Queue;
use MailScanner::RBLs;
use MailScanner::MCPMessage;
use MailScanner::Message;
use MailScanner::MCP;
use MailScanner::SA;
use MailScanner::SweepContent;
use MailScanner::SweepOther;
use MailScanner::SweepViruses;
use MailScanner::TNEF;
use MailScanner::Unzip;
use MailScanner::WorkArea;
use MailScanner;

my $autoinstalled=0;
# To detect whether we've been auto-configured & installed
# -- $autoinstalled will be set to 1 if so.
#@@$autoinstalled=1;

# Needed for Sys::Syslog, as Debian Potato (at least) doesn't
# appear to have "gethostname" syscall as used (indirectly) by Sys::Syslog
# So it uses `hostname` instead, which it can't do if PATH is tainted.
# It's good to have this anyway, although we may need to modify it for
# other OS when we find that something we need isn't here -- nwp 14/01/02
$ENV{PATH}="/sbin:/bin:/usr/sbin:/usr/bin";

# We *really* should clear *all* environment bar what we *know* we
# need here. It will avoid surprises (like bash running BASH_ENV or
# SpamAssassin using $ENV{HOME} rather than getpwnam to decide where
# to drop its load.

# Needed for -T:
delete $ENV{'BASH_ENV'}; # Don't run things on bash startup

# Needed for SpamAssassin:
delete $ENV{'HOME'};

# Need the parent process to ignore SIGHUP, and catch SIGTERM
$SIG{'HUP'} = 'IGNORE';
$SIG{'TERM'} = \&ExitParent;

# Remember to update this before releasing a new version of MailScanner.
#
# Version numbering scheme is this:
# 4   Major release
# 00  Minor release, incremented for new features and major changes
# 0   Incremented for bug fixes and beta releases
# Any numbers after a "-" are packaging release numbers. They reflect
# changes in the packaging, and occasionally very small changes to the code.
#
# First production release will be 4.00.1.
#
$MailScanner::Config::MailScannerVersion = '5.3.4';

my $WantHelp          = 0;
my $Versions          = 0;
my $WantProcDBDumpOnly= -1;
my $WantLintOnly      = 0;
my $WantLintLiteOnly  = 0;
my $WantChangedOnly   = 0;
my $WantRuleCheck     = "";
my $RuleCheckFrom     = "";
my @RuleCheckTo       = "";
my $RuleCheckIP       = "";
my $RuleCheckVirus    = "";
my $IDToScan          = "";
my $DirToScan         = "";
my $PidFile           = "";
my $Debug             = "";
my $DebugSpamAssassin = 0;
my $result = GetOptions ("h|H|help"            => \$WantHelp,
                         "v|V|version|Version" => \$Versions,
                         "lint"                => \$WantLintOnly,
                         "lintlite|lintlight"  => \$WantLintLiteOnly,
                         "processing:1"        => \$WantProcDBDumpOnly,
                         "c|C|changed"         => \$WantChangedOnly,
                         "value=s"             => \$WantRuleCheck,
                         "from=s"              => \$RuleCheckFrom,
                         "to=s@"               => \@RuleCheckTo,
                         "ip=s"                => \$RuleCheckIP,
                         "inqueuedir=s"        => \$DirToScan,
                         "virus=s"             => \$RuleCheckVirus,
                         "id=s"                => \$IDToScan,
                         "debug"               => \$Debug,
                         "debug-sa"            => \$DebugSpamAssassin);

if ($WantHelp) {
  print STDERR "Usage:\n";
  print STDERR "MailScanner [ -h|-v|--debug|--debug-sa|--lint ] |\n";
  print STDERR "            [ --processing | --processing=<minimum> ] |\n";
  print STDERR "            [ -c|--changed ] |\n";
  print STDERR "            [ --id=<message-id> ] |\n";
  print STDERR "            [ --inqueuedir=<dir-name|glob> ] |\n";
  print STDERR "            [--value=<option-name> --from=<from-address>\n";
  print STDERR "             --to=<to-address>,    --to=<to-address-2>, ...]\n";
  print STDERR "             --ip=<ip-address>,    --virus=<virus-name> ]\n";
  print STDERR "            <MailScanner.conf-file-location>\n";
  exit 0;
}

# Are we just printing version numbers and exiting?
if ($Versions) {
  my @Modules = qw/AnyDBM_File Archive::Zip bignum Carp Compress::Zlib Convert::BinHex Convert::TNEF Data::Dumper Date::Parse DirHandle Fcntl File::Basename File::Copy FileHandle File::Path File::Temp Filesys::Df HTML::Entities HTML::Parser HTML::TokeParser IO::File IO::Pipe Mail::Header Math::BigInt Math::BigRat MIME::Base64 MIME::Decoder MIME::Decoder::UU MIME::Head MIME::Parser MIME::QuotedPrint MIME::Tools Net::CIDR Net::IP OLE::Storage_Lite Pod::Escapes Pod::Simple POSIX Scalar::Util Socket Storable Sys::Hostname::Long Sys::Syslog Test::Pod Test::Simple Time::HiRes Time::localtime/;
  my @Optional = qw#Archive/Tar.pm bignum.pm Business/ISBN.pm Business/ISBN/Data.pm Data/Dump.pm DB_File.pm DBD/SQLite.pm DBI.pm Digest.pm Digest/HMAC.pm Digest/MD5.pm Digest/SHA1.pm Encode/Detect.pm Error.pm ExtUtils/CBuilder.pm ExtUtils/ParseXS.pm Getopt/Long.pm Inline.pm IO/String.pm IO/Zlib.pm IP/Country.pm Mail/ClamAV.pm Mail/SpamAssassin.pm Mail/SPF.pm Mail/SPF/Query.pm Module/Build.pm Net/CIDR/Lite.pm Net/DNS.pm Net/DNS/Resolver/Programmable.pm Net/LDAP.pm NetAddr/IP.pm Parse/RecDescent.pm SAVI.pm Test/Harness.pm Test/Manifest.pm Text/Balanced.pm URI.pm version.pm YAML.pm#;
  my($module, $s, $v, $m);

  printf("Running on\n%s", `uname -a`);
  printf("This is %s", `cat /etc/redhat-release`)   if -f "/etc/redhat-release";
  printf("This is %s", `head -1 /etc/SuSE-release`) if -f "/etc/SuSE-release";
  printf("This is Perl version %f (%vd)\n", $], $^V);
  print "\nThis is MailScanner version " . $MailScanner::Config::MailScannerVersion . "\n";
  print "Module versions are:\n";
  open STDERR, "> /dev/null";
  foreach $module (@Modules) {
    $s = "use $module; \$$module" . '::VERSION';
    $v = eval("$s") || "missing";
    print "$v\t$module\n" if $v ne "";
  }
  print "\nOptional module versions are:\n";
  foreach $module (@Optional) {
    $m = $module;
    $m =~ s/\//::/g;
    $m =~ s/\.pm$//;
    $s = '$' . "$m" . '::VERSION';
    $v = eval("require \"$module\"; $s") || "missing";
    print "$v\t$m\n";
  }
  exit;
}

# Set the Debug flag if the DebugSpamAssassin flag was set
$Debug = 1 if $DebugSpamAssassin;

# Check version of MIME-tools against its requirements
my $error = 0;
if ($MIME::Tools::VERSION > 5.420) {
  # They have a new MIME-tools so must have new File::Temp
  if ($IO::VERSION<1.23) {
    print STDERR "\n\n**** ERROR: You must upgrade your perl IO module to at least\n**** ERROR: version 1.2301 or MailScanner will not work!\n\n";
    $error = 1;
  }
  if ($IO::Stringy::VERSION<2.110) {
    print STDERR "\n\n**** ERROR: You must upgrade your perl IO::Stringy module to at least\n**** ERROR: version 2.110 or MailScanner will not work!\n\n";
    $error = 1;
  }
}
exit 1 if $error;

# Work out what directory we're in and add it onto the front
# of the include path so that we can work if we're just chucked
# any old where in a directory with the modules. Also add
# ./MailScanner 
#
# Also get process name while we're at it.
#
my $dir = $0;
# can't use s/// as it doesn't untaint $dir
$dir =~ m#^(.*)/([^/]+)$#;
$dir = $1;
$MailScanner::Config::MailScannerProcessCommand = "$1/$2";
$MailScanner::Config::MailScannerProcessName = ""; # Avoid 'used only once' warning BS.
$MailScanner::Config::MailScannerProcessName = $2;
# Add my directory onto the front of the include path
unless ($autoinstalled) {
  unshift @INC, "$dir/MailScanner";
  unshift @INC, $dir;
}

# Set umask nice and safe so no-one else can access anything!
umask 0077;

# Fix bug in GetOptions where it rarely leaves switches on the command-line.
if ($WantLintOnly || $WantLintLiteOnly) {
  shift unless -f $ARGV[0];
}
# Find the mailscanner.conf file, with a default just in case.
my $ConfFile = $ARGV[0];
# Use the default if we couldn't find theirs. Will save a lot of grief.
$ConfFile = '/etc/MailScanner/MailScanner.conf' if $ConfFile eq "" ||
                                                       !(-f $ConfFile);
# Tell ConfigSQL where the configuration file is. 
$MailScanner::ConfigSQL::ConfFile = $ConfFile;

# Do they just want a dump of the processing-database table?
if ($WantProcDBDumpOnly>=0) {
  my $dbname = MailScanner::Config::QuickPeek($ConfFile,
                                              'processingattemptsdatabase');
  if ($dbname && -f $dbname) {
    DumpProcessingDatabase($dbname, $WantProcDBDumpOnly);
  }
  exit 0;
}

# Check the MailScanner version number against what is in MailScanner.conf
my $NeedVersion = MailScanner::Config::QuickPeek($ConfFile,
                                              'mailscannerversionnumber');
if ($NeedVersion) {
  my($ConfMajor, $ConfMinor, $ConfRelease);
  my($Error, $AreMajor, $AreMinor, $AreRelease);
  $Error = 0;
  $NeedVersion =~ /^(\d+)\.(\d+)\.(\d+)$/;
  ($ConfMajor, $ConfMinor, $ConfRelease) = ($1+0, $2+0, $3+0);
  $ConfMajor   = 0 unless $ConfMajor;
  $ConfMinor   = 0 unless $ConfMinor;
  $ConfRelease = 0 unless $ConfRelease;
  $MailScanner::Config::MailScannerVersion =~ /^(\d+)\.(\d+)\.(\d+)$/;
  ($AreMajor, $AreMinor, $AreRelease) = ($1+0, $2+0, $3+0);
  $AreMajor   = 0 unless $AreMajor;
  $AreMinor   = 0 unless $AreMinor;
  $AreRelease = 0 unless $AreRelease;
  if ($ConfMajor > $AreMajor) {
    $Error = 1;
  } elsif ($ConfMajor == $AreMajor) {
    if ($ConfMinor > $AreMinor) {
      $Error = 1;
    } elsif ($ConfMinor == $AreMinor) {
      if ($ConfRelease > $AreRelease) {
        $Error = 1;
      }
    }
  }
  if ($Error) {
    print STDERR "The configuration file $ConfFile\nis too new for this version of MailScanner.\nThis is version " . $MailScanner::Config::MailScannerVersion . " but the config file is for at least version $NeedVersion\n";
    exit 1;
  }
}

# Check they have configured a virus scanner and the name of their site.
if (MailScanner::Config::QuickPeek($ConfFile, 'virusscanners', 'notifldap')
                      eq "none" && !$WantLintLiteOnly) {
  print STDERR <<EONONE;

Currently you are using no virus scanners.
This is probably not what you want.

In your /etc/MailScanner/MailScanner.conf file, set
    Virus Scanners = clamav
Then install it with your package manager or download it directly from
http://www.clamav.net

EONONE
}

my $NotConfigured = 0;
$NotConfigured++ if MailScanner::Config::QuickPeek($ConfFile,
                                                   '%org-name%', 'notifldap')
                      =~ /yoursite|unconfigured-\w+-site/i;
$NotConfigured++ if MailScanner::Config::QuickPeek($ConfFile,
                                                   '%org-long-name%',
                                                   'notifldap')
                      eq "Your Organisation Name Here";
$NotConfigured++ if MailScanner::Config::QuickPeek($ConfFile,
                                                   '%web-site%', 'notifldap')
                      eq "www.your-organisation.com";
if ($NotConfigured == 3) {
  # Set them all to be something sensible
  my $domain_name = hostname_long;
  $domain_name =~ s/^[^.]+\.//;
  my $header_domain = $domain_name;
  $header_domain =~ tr/./_/; # So as not to kill Symantec's broken scanner

  MailScanner::Config::SetPercent('org-name', $header_domain);
  MailScanner::Config::SetPercent('org-long-name', $domain_name);
  MailScanner::Config::SetPercent('web-site', 'www.' . $domain_name);
}
# Set an indication of the version number for rules.
MailScanner::Config::SetPercent('version', $MailScanner::Config::MailScannerVersion);

# Load the MTA modules we need
my($MTAmod, $MTADSmod);
# LEOH:if (MailScanner::Config::QuickPeek($ConfFile, 'mta') =~ /exim/i) {
$_=MailScanner::Config::QuickPeek($ConfFile, 'mta');
$_='sendmail' if $WantLintOnly || $WantLintLiteOnly || $WantRuleCheck;
if (/exim/i) {
  $MTAmod = 'Exim.pm';
  $MTADSmod = 'EximDiskStore.pm';
} elsif(/zmailer/i) {
  $MTAmod = 'ZMailer.pm';
  $MTADSmod = 'ZMDiskStore.pm';
} elsif(/postfix/i) {
  $MTAmod = 'Postfix.pm';
  $MTADSmod = 'PFDiskStore.pm';
} elsif(/qmail/i) {
  $MTAmod = 'Qmail.pm';
  $MTADSmod = 'QMDiskStore.pm';
} elsif(/msmail/i) {
  $MTAmod = 'MSMail.pm';
  $MTADSmod = 'MSDiskStore.pm';
} else {
  $MTAmod = 'Sendmail.pm';
  $MTADSmod = 'SMDiskStore.pm';
}
require "MailScanner/$MTAmod";
require "MailScanner/$MTADSmod";

# All they want is the list of settings that have been changed from the
# default values hard-coded into ConfigDefs.pl. These values may well be
# different from those supplied in the default MailScanner.conf file.
if ($WantChangedOnly) {
  MailScanner::Config::Read($ConfFile);
  MailScanner::Config::PrintNonDefaults();
  exit 0;
}

# If all we are doing is linting the configuration file, then do it here
# and get out.
if ($WantLintOnly || $WantLintLiteOnly) {

  # Start logging to syslog/stderr
  MailScanner::Log::WarningsOnly() if $WantLintLiteOnly;
  StartLogging($ConfFile);
  my $logbanner = "MailScanner Email Processor version " .
                  $MailScanner::Config::MailScannerVersion .
                  " checking configuration...\n";
  MailScanner::Log::Configure($logbanner, 'stderr');

  # Check -autoupdate lock files
  my $lockdir = MailScanner::Config::QuickPeek($ConfFile, 'lockfiledir');
  if ($lockdir eq "" || $lockdir =~ /tmp$/i) {
    print STDERR "Please move your \"Lockfile Dir\" setting in MailScanner.conf.\n";
    print STDERR "It should point outside /tmp, preferably /var/spool/MailScanner/incoming/Locks\n";
  }
  my $cluid = MailScanner::Config::QuickPeek($ConfFile, 'runasuser');
  my $clgid = MailScanner::Config::QuickPeek($ConfFile, 'runasgroup');
  my $clr = system("/usr/sbin/ms-create-locks \"$lockdir\" \"$cluid\" \"$clgid\"");
  print STDERR "Error: Attempt to create locks in $lockdir failed!\n"
    if ($clr>>8) != 0;

  # Read the directory containing all the custom code
  MailScanner::Config::initialise(MailScanner::Config::QuickPeek($ConfFile,
                                  'customfunctionsdir'));

  # Read the configuration file properly
  print STDERR "\n";
  MailScanner::Config::Read($ConfFile);
  print STDERR "\n";

  # Tried to set [u,g]id after writing pid, but then it fails when it re-execs
  # itself. Using the posix calls because I don't want to have to bother to
  # find out what happens when "$< = $uid" fails (i.e. not running as root).
  # This needs to be global so checking functions can all get at them.
  # This now also adds group membership for the quarantine and work directories.
  my($uname, $gname, $qgname, $igname, $uid, $gid, $qgid, $igid);
  $uname = MailScanner::Config::Value('runasuser');
  $gname = MailScanner::Config::Value('runasgroup');
  $qgname= MailScanner::Config::Value('quarantinegroup');
  $igname= MailScanner::Config::Value('workgroup');

  $uid   = $uname?getpwnam($uname):0;
  $gid   = $gname?getgrnam($gname):0;
  $qgid  = $qgname?getgrnam($qgname):0;
  $igid  = $igname?getgrnam($igname):0;

  # Check the version number in MailScanner.conf is correct.
  my($currentver, $confver);
  $currentver = $MailScanner::Config::MailScannerVersion;
  $confver = MailScanner::Config::Value('mailscannerversionnumber');
  #print STDERR "Running ver = $currentver\nConf ver = $confver\n";
  unless ($WantLintLiteOnly) {
   print STDERR "Checking version numbers...\n";
   if ($currentver ne $confver) {
    print STDERR "Version installed ($currentver) does not match version stated in\nMailScanner.conf file ($confver), you may want to run ms-upgrade-conf\nto ensure your MailScanner.conf file contains all the latest settings.\n";
   } else {
    print STDERR "Version number in MailScanner.conf ($confver) is correct.\n";
   }
  }

  my $mailheader = MailScanner::Config::Value('mailheader');
  if ($mailheader !~ /^[_a-zA-Z0-9-]+:?$/) {
    print STDERR "\n";
    print STDERR "Your setting \"Mail Header\" contains illegal characters.\n";
    print STDERR "This is most likely caused by your \"%org-name%\" setting\n";
    print STDERR "which must not contain any spaces, \".\" or \"_\" characters\n";
    print STDERR "as these are known to cause problems with many mail systems.\n";
    print STDERR "\n";
  }

  # Check that unrar is installed
  if ($WantLintOnly) {
   my $unrar = MailScanner::Config::Value('unrarcommand');
   unless (-x $unrar) {
    print STDERR "\n";
    print STDERR "Unrar is not installed, it should be in $unrar.\n";
    print STDERR "This is required for RAR archives to be read to check\n";
    print STDERR "filenames and filetypes. Virus scanning is not affected.\n";
    print STDERR "\n";
   }
  }

  # Check envelope_sender_header in spamassassin.conf is correct
  if ($WantLintOnly) {
   my($msfromheader, $etc, $saprefs);
   $msfromheader = MailScanner::Config::Value('envfromheader');
   $msfromheader =~ s/:$//;
   $etc = $1 if $ConfFile =~ m#^(.*)/[^/]+$#;
   $saprefs = new FileHandle("$etc/spamassassin.conf");
   if ($saprefs) {
    while(defined($_=<$saprefs>)) {
      chomp;
      if (s/^\s*envelope_sender_header\s+//) {
        if ($msfromheader ne $_) {
          print STDERR "\nERROR: The \"envelope_sender_header\" in your spamassassin.conf\n";
          print STDERR "ERROR: is not correct, it should match $msfromheader\n\n";
        } else {
          print STDERR "\nYour envelope_sender_header in spamassassin.conf is correct.\n";
        }
        last;
      }
    }
    $saprefs->close();
   } else {
    print STDERR "\nWarning: I could not read your spamassassin.conf file!\n\n";
   }
  }

  # Check permissions on /tmp
  if ($WantLintOnly) {
    my $handle = IO::File->new_tmpfile or print STDERR "\nYour /tmp needs to be set to \"chmod 1777 /tmp\"\n";
    close($handle);
  }

  # If it's a "light" check, then just bail out here, I've checked enough.
  exit if $WantLintLiteOnly;

  # Need to find the PidFile before changing uid/gid as its ownership will need
  # to be set to the new uid/gid. It must be created first if necessary.
  # Need     PidFile     to be able to manage pid of parent process
  # JKF 8 aug 2007 commented this out as it just screws up running processes
  #$PidFile = MailScanner::Config::Value('pidfile');
  #WritePIDFile("MailScanner");
  #chown $uid, $gid, $PidFile;

  my $workarea = new MailScanner::WorkArea;
  my $inqueue  = new MailScanner::Queue(
                     @{MailScanner::Config::Value('inqueuedir')});
  my $mta      = new MailScanner::Sendmail;
  my $quar     = new MailScanner::Quarantine;

  $global::MS = new MailScanner(WorkArea   => $workarea,
                                InQueue    => $inqueue,
                                MTA        => $mta,
                                Quarantine => $quar);
  SetUidGid($uid, $gid, $qgid, $igid);

  # Other initialisation needed to fake a batch for scanner testing
  MailScanner::MessageBatch::initialise();
  print STDERR "\nChecking for SpamAssassin errors (if you use it)...\n";
  MailScanner::SA::CreateTempDir($uid,
                          MailScanner::Config::Value('spamassassintempdir'))
    unless MailScanner::Config::IsSimpleValue('usespamassassin') &&
           !MailScanner::Config::Value('usespamassassin');
  MailScanner::SA::initialise(0,1); # Just do a Lint check
  MailScanner::Log::Reset();
  MailScanner::TNEF::initialise();
  MailScanner::Sendmail::initialise();
  MailScanner::SweepViruses::initialise();
  CreateProcessingDatabase(1); # Just do a Lint check
  #my $workarea = new MailScanner::WorkArea;
  #my $inqueue  = new MailScanner::Queue(
  #                   @{MailScanner::Config::Value('inqueuedir')});
  #my $mta      = new MailScanner::Sendmail;
  #my $quar     = new MailScanner::Quarantine;
  #$global::MS = new MailScanner(WorkArea   => $workarea,
  #                              InQueue    => $inqueue,
  #                              MTA        => $mta,
  #                              Quarantine => $quar);
  MailScanner::Lock::initialise();
  #print STDERR "\nLock type = " . MailScanner::Lock::ReportLockType() . "\n";

  # Find the list of virus scanners installed
  print STDERR "MailScanner.conf says \"Virus Scanners = " .
               MailScanner::Config::Value('virusscanners') . "\"\n";
  my @scannerlist = MailScanner::SweepViruses::InstalledScanners();
  print STDERR "Found these virus scanners installed: " .
               join(', ', @scannerlist) . "\n";
  print STDERR "=" x 75 . "\n";

  # Create a fake message batch containing EICAR and virus-scan it
  my $batch;
  $workarea->Clear();
  $batch = new MailScanner::MessageBatch('lint', undef);
  $global::MS->{batch} = $batch;
  $global::MS->{work}->BuildInDirs($batch);
  $batch->Explode($Debug);

  $batch->CreateEntitiesHelpers();
  MailScanner::Config::SetValue('showscanner',1); # Over-ride config setting
  $batch->VirusScan();
  
  # Print all the v infections in the batch
  my $m = $batch->{messages}->{"1"};
  my $rep = $m->{virusreports}->{'neicar.com'};
  my @rep = split "\n", $rep;
  print STDERR "=" x 75 . "\n";
  print STDERR "Virus Scanner test reports:\n" if @rep;
  foreach my $l (@rep) {
    my ($scanner, $report) = split /:/, $l, 2;
    chomp $report;
    $report =~ s/^\s+//g;
    $report =~ s/\s+$//g;
    print STDERR $scanner . " said \"$report\"\n";
  }
  my $scannerlist = join(',', @scannerlist);
  print STDERR <<EOWarn;

If any of your virus scanners ($scannerlist)
are not listed there, you should check that they are installed correctly
and that MailScanner is finding them correctly via its virus.scanners.conf.
EOWarn

  $workarea->Destroy();
  MailScanner::Config::EndCustomFunctions();
  MailScanner::Config::DisconnectLDAP();
  MailScanner::Log::Stop();
  unlink "/tmp/MSLint.body.$$";
  exit 0;
}

# Do they want us to work out the value of a rule
if ($WantRuleCheck ne "") {
  my($rule,$user,$domain,$to,$msg,$result);

  # Read the configuration file properly
  MailScanner::Config::Read($ConfFile);

  # Need to fake that we're running sendmail for the static code to work,
  # just like in --lint ($WantLintOnly).
  my $workarea = new MailScanner::WorkArea;
  my $inqueue  = new MailScanner::Queue(
                     @{MailScanner::Config::Value('inqueuedir')});
  my $mta      = new MailScanner::Sendmail;
  my $quar     = new MailScanner::Quarantine;
  $global::MS = new MailScanner(WorkArea   => $workarea,
                                InQueue    => $inqueue,
                                MTA        => $mta,
                                Quarantine => $quar);

  # We have external configuration name, first translate it to internal
  $WantRuleCheck = lc($WantRuleCheck);
  $WantRuleCheck =~ s/[^a-z0-9]//g; # Leave numbers and letters only
  $rule          = MailScanner::Config::EtoI($WantRuleCheck);
  $rule          = $WantRuleCheck if $rule eq "";

  $msg = MailScanner::Message->new('1','/tmp','fake');

  $RuleCheckFrom = lc($RuleCheckFrom);
  ($user, $domain) = ($1,$2) if $RuleCheckFrom =~ /^([^@]*)@(.*)$/;
  $msg->{from}       = $RuleCheckFrom;
  $msg->{fromdomain} = $domain;
  $msg->{fromuser}   = $user;

  $msg->{clientip}   = $RuleCheckIP;
  %{$msg->{allreports}} = ();
  $msg->{allreports}{""} = $RuleCheckVirus;

  foreach $to (@RuleCheckTo) {
    $to = lc($to);
    next unless $to;
    ($user, $domain) = ($1,$2) if $to =~ /^([^@]*)@(.*)$/;
    push @{$msg->{to}}, $to;
    push @{$msg->{todomain}}, $domain;
    push @{$msg->{touser}}, $user;
  }

  $result = MailScanner::Config::Value($rule, $msg);
  print STDERR "Looked up internal option name \"$rule\"\n";
  print STDERR "With sender = " . $msg->{from} . "\n";
  foreach $to (@{$msg->{to}}) {
    next unless $to;
    print STDERR "  recipient = " . $to . "\n";
  }
  print STDERR "Client IP = " . $msg->{clientip} . "\n";
  print STDERR "Virus = " . $msg->{allreports}{""} . "\n";
  print STDERR "Result is \"$result\"\n";
  print STDERR "\n0=No 1=Yes\n" if $result =~ /^[01]$/;

  exit 0;
}

## We are probably running for real by now, not in any "check a few things
## and then quit" mode such as --lint or --versions, so do a quick syntax
## check of the entire configuration before we fork off any children.
#MailScanner::Config::Read($ConfFile, 'ThrowItAllAway');


# In case we lose privs to the file later, delete the SA signaller now
my $startlock = MailScanner::Config::QuickPeek($ConfFile, 'lockfiledir') .
                '/MS.bayes.starting.lock';
unlink $startlock if $startlock && -f $startlock;

# Tried to set [u,g]id after writing pid, but then it fails when it re-execs
# itself. Using the posix calls because I don't want to have to bother to
# find out what happens when "$< = $uid" fails (i.e. not running as root).
# This needs to be global so checking functions can all get at them.
# This now also adds group membership for the quarantine and work directories.
my($uname, $gname, $qgname, $igname, $uid, $gid, $qgid, $igid);
$uname = MailScanner::Config::QuickPeek($ConfFile, 'runasuser');
$gname = MailScanner::Config::QuickPeek($ConfFile, 'runasgroup');
$qgname= MailScanner::Config::QuickPeek($ConfFile, 'quarantinegroup');
$igname= MailScanner::Config::QuickPeek($ConfFile, 'incomingworkgroup');
$uid   = $uname?getpwnam($uname):0;
$gid   = $gname?getgrnam($gname):0;
$qgid  = $qgname?getgrnam($qgname):0;
$igid  = $igname?getgrnam($igname):0;

# Need to find the PidFile before changing uid/gid as its ownership will need
# to be set to the new uid/gid. It must be created first if necessary.
# Need     PidFile     to be able to manage pid of parent process
$PidFile = MailScanner::Config::QuickPeek($ConfFile, 'pidfile');
WritePIDFile("MailScanner");
chown $uid, $gid, $PidFile;

# Create the SpamAssassin temporary working dir
MailScanner::SA::CreateTempDir($uid,
      MailScanner::Config::QuickPeek($ConfFile, 'spamassassintemporarydir'));

# Check and create -autoupdate lock files
my $locksdir = MailScanner::Config::QuickPeek($ConfFile, 'lockfiledir');
if ($locksdir eq "" || $locksdir =~ /tmp$/i) {
  print STDERR "Please move your \"Lockfile Dir\" setting in MailScanner.conf.\n";
  print STDERR "It should point outside /tmp, preferably /var/spool/MailScanner/incoming/Locks\n";
}
my $cl = system("/usr/sbin/ms-create-locks \"$locksdir\" \"$uname\" \"$gname\"");
print STDERR "Error: Attempt to create locks in $locksdir failed!\n"
 if ($cl>>8) != 0;

SetUidGid($uid, $gid, $qgid, $igid);
CheckModuleVersions();
# Can't do this here, config not read yet: CheckQueuesAreTogether();

#
# Need MaxChildren to know how many children to fork
#      Debug       to know whether to terminate
#      WorkDir     to be able to clean up after killed children
#      BayesRebuildPeriod to be able to rebuild the Bayes database regularly
#
use vars qw($RunInForeground);
$RunInForeground= MailScanner::Config::QuickPeek($ConfFile, 'runinforeground');
my $MaxChildren = MailScanner::Config::QuickPeek($ConfFile, 'maxchildren');
   $Debug      .= MailScanner::Config::QuickPeek($ConfFile, 'debug');
my $WorkDir     = MailScanner::Config::QuickPeek($ConfFile, 'incomingworkdir');
my $BayesRebuildPeriod = MailScanner::Config::QuickPeek($ConfFile, 'rebuildbayesevery');
# FIXME: we should check that the ownership and modes on piddir do not
# allow random people to do nasty things in there (like create symlinks
# to critical system files, or create pidfiles that point to critical
# system processes)
$Debug = ($Debug =~ /yes|1/i)?1:0;
$RunInForeground = 0 unless $RunInForeground =~ /yes|1/i;

my $WantLiteCheck = MailScanner::Config::QuickPeek($ConfFile, 'automaticsyntaxcheck');
if ($WantLiteCheck =~ /1|y/i) {
  #print STDERR "About to run $0 --lintlite $ConfFile\n";
  system($MailScanner::Config::MailScannerProcessCommand . " --lintlite $ConfFile");
  #exit();
}

# Enable STDOUT flushing if running in foreground
# to be able to actively capture it with a logger
$| = 1 if $RunInForeground;

# Give the user their shell back
ForkDaemon($Debug);

# Only write the parent pid, not the children yet
WritePIDFile($$);

#
# Do it only once when debugging.
#
if ($Debug) {
  my $mailheader = MailScanner::Config::QuickPeek($ConfFile, 'mailheader');
  #print STDERR "Mail Header is \"$mailheader\"\n";
  if ($mailheader !~ /^[_a-zA-Z0-9-]+:?$/) {
    print STDERR <<EOMAILHEADER;

************************************************************************
In MailScanner.conf, your "%org-name%" or "Mail Header" setting
contains spaces and/or other illegal characters.

Including any spaces will break all your mail system (but do not worry,
MailScanner will fix this for you on the fly).

Otherwise, it should only contain characters from the set a-z, A-Z,
0-9, "-" and "_". While theoretically some other characters are allowed,
some commercial mail systems fail to handle them correctly.

This is clearly noted in the MailScanner.conf file, immediately above
the %org-name% setting. Please read the documentation!
************************************************************************

EOMAILHEADER
  }
  WorkForHours();
  print STDERR "Stopping now as you are debugging me.\n";
  exit 0;
}


#
# Start forking off child workers.
#

setpgrp();
$MaxChildren = 1 if $MaxChildren<1; # You can't have 0 workers
my $NumberOfChildren = 0;
my %Children;
my $NextRebuildDueTime = 0;
my $RebuildDue = 0;
# Set when the next rebuild is due if regular rebuilds are being done
$NextRebuildDueTime = time + $BayesRebuildPeriod if $BayesRebuildPeriod;

# If we run in foreground, SIGKILL to the parent will try to reload
# by SIGKILLing its children
$SIG{'HUP'} = 'ReloadParent'; # JKF 20060731 if $RunInForeground;

for (;;) {
  while($NumberOfChildren < $MaxChildren) {
    $0 = 'MailScanner: starting children';
    # Trigger 1 Bayes rebuild if the period has expired
    $RebuildDue = 0;
    if (time > $NextRebuildDueTime && $BayesRebuildPeriod > 0) {
      $RebuildDue = 1;
      $NextRebuildDueTime = time + $BayesRebuildPeriod;
    }
    print STDOUT sprintf("About to fork child #%d of %d...\n",
                         $NumberOfChildren+1, $MaxChildren)
      if $RunInForeground;
    my $born_pid = fork();
    if (!defined($born_pid)) {
      die "Cannot fork off child process, $!";
    }
    if ($born_pid == 0) {
      # I am a child process.
      # Set up SIGHUP handler and
      # Run MailScanner for a few hours.
      WorkForHours($RebuildDue);
      exit 0;
    }
    print STDOUT "\tForked OK - new child is [$born_pid]\n" if $RunInForeground;
    # I am the parent process.
    $Children{$born_pid} = 1;
    $NumberOfChildren++;
    sleep 5; # Dropped this from 11 2006-11-01
  }

  # I have started enough children. Let's wait for one to die...
  my $dying_pid;
  $0 = 'MailScanner: master process sleeping';
  until (($dying_pid = wait()) == -1) {
    my $exitstatus = $?;

    $0 = 'MailScanner: waiting for children to die';
    #if ($dying_pid == -1) {
    #  warn "We haven't got any child processes, which isn't right!, $!";
    #}
    if ($dying_pid>0 && exists($Children{$dying_pid})) {
      # Knock the dying process off the list and decrement the counter.
      delete $Children{$dying_pid};
      $NumberOfChildren--;
      # Don't have Pid files for children any more
      # DeletePIDFile($dying_pid);

      if ($exitstatus) {
        # $? = (exit_status << 8) | (signal_it_died_from)
        my $code = $exitstatus >> 8;
        my $signal = $exitstatus & 0xFF;

        MailScanner::Log::WarnLog("Process did not exit cleanly, returned " .
                                  "%d with signal %d", $code, $signal);
      }

      # Clean up after the dying process in case it left a mess.
      # If they change the work dir they really will have to stop and re-start.
      rmtree("$WorkDir/$dying_pid", 0, 1) if -d "$WorkDir/$dying_pid";

      #
      # Re-spawn a replacement child process
      #
      # Trigger 1 Bayes rebuild if the period has expired
      $RebuildDue = 0;
      if (time > $NextRebuildDueTime && $BayesRebuildPeriod > 0) {
        $RebuildDue = 1;
        $NextRebuildDueTime = time + $BayesRebuildPeriod;
      }
      print STDOUT sprintf("About to re-fork child #%d of %d...\n",
                           $NumberOfChildren+1, $MaxChildren)
        if $RunInForeground;
      $0 = 'MailScanner: starting child';
      my $born_pid = fork();
      if (!defined($born_pid)) {
        die "Cannot fork off child process, $!";
      }
      if ($born_pid == 0) {
        # I am a child process.
        # Set up SIGHUP handler and
        # Run MailScanner for a few hours.
        WorkForHours($RebuildDue);
        exit 0;
      }
      print STDOUT "\tRe-forked OK - new child is [$born_pid]\n"
        if $RunInForeground;
      # I am the parent process.
      $Children{$born_pid} = 1;
      $NumberOfChildren++;
      sleep 2; # Dropped this from 11 2006-11-01
    } else {
      warn "We have just tried to reap a process which wasn't one of ours!, $!";
    }
  }
}

#if ($Debug) {
#  print STDERR "Stopping now as you are debugging me.\n";
#  exit 0;
#}

print STDERR "Oops, tried to go into Never Never Land!\n";
exit 1;

#
#
#
#
#
# The End
#
#
#
#
#

#
# Start each of the worker processes here.
# Just run for a few hours and then terminate.
# If we are debugging, then just run once.
#
sub WorkForHours {
  my ($BayesRebuild) = @_; # Should we start by rebuilding Bayes databases

  # Tell ConfigSQL that this is now a child
  $MailScanner::ConfigSQL::child = 1;

  # Read the configuration file and start logging to syslog/stderr
  StartLogging($ConfFile);

  # Check the programs listed in SystemDefs.pl as some of them
  # might be wrong
  # This is now obsolete as all references to it have been removed
  #CheckSystemDefs();

  # Setup SIGHUP and SIGTERM handlers
  $SIG{'HUP'}  = \&ExitChild;
  #$SIG{'CHLD'}  = \&Reaper; # Addition by Bart Jan Buijs
  $SIG{'TERM'} = 'DEFAULT';

  # Read the directory containing all the custom code
  MailScanner::Config::initialise(MailScanner::Config::QuickPeek($ConfFile,
                                  'customfunctionsdir'));

  # Read the configuration file properly
  MailScanner::Config::Read($ConfFile);

  # If they have set Debug SpamAssassin = yes, ignore unless Debug is also set
  unless (MailScanner::Config::Value('debug') =~ /1/) {
    MailScanner::Config::SetValue('debugspamassassin', 0);
  }

  # Over-ride the incoming queue directory if necessary
  MailScanner::Config::OverrideInQueueDirs($DirToScan) if $DirToScan;

  # Check the home directory exists and is writable,
  # otherwise SA will fail, as it wants to write Bayes databases and all
  # sorts of other stuff in the home directory.
  CheckHomeDir()
    if MailScanner::Config::Value('spamassassinuserstatedir') eq "";

  # Initialise class variables now we are the right user
  MailScanner::MessageBatch::initialise();
  MailScanner::MCP::initialise();
  MailScanner::Log::InfoLog("Bayes database rebuild is due") if $BayesRebuild;
  $MailScanner::SA::Debug = $DebugSpamAssassin ||
                            MailScanner::Config::Value('debugspamassassin');
  MailScanner::SA::initialise($BayesRebuild);
  MailScanner::Log::Reset();
  MailScanner::TNEF::initialise();
  # Setup the Sendmail and Sendmail2 variables if they aren't set yet
  MailScanner::Sendmail::initialise();
  CheckQueuesAreTogether(); # Can only do this after reading conf file
  MailScanner::SweepViruses::initialise(); # Setup Sophos SAVI library
  CreateProcessingDatabase();

  my $workarea = new MailScanner::WorkArea;
  my $inqueue  = new MailScanner::Queue(
                     @{MailScanner::Config::Value('inqueuedir')});
  my $mta      = new MailScanner::Sendmail;
  my $quar     = new MailScanner::Quarantine;

  $global::MS = new MailScanner(WorkArea   => $workarea,
                                InQueue    => $inqueue,
                                MTA        => $mta,
                                Quarantine => $quar);

  # Setup the lock type depending on which MTA we are using
  MailScanner::Lock::initialise();

  # Clean up the entire outgoing sendmail queue in case I was
  # killed off half way through processing some messages.
  # JKF Can't do this easily any more as the outgoing queue dir is the
  # result of a ruleset.
  # And I can't work out which class to put it in :-(
  #my($CleanUpList);
  #$CleanUpList = $global::MS->{inq}->ListWholeQueue(
  #                 $global::MS->{inq}->{dir});
  #Sendmail::ClearOutQueue($CleanUpList, $Config::OutQueueDir);

  my $batch; # Looks pretty insignificant, doesn't it? :-)

  # Restart periodically, and handle time_t rollover in the year 2038
  my($StartTime, $RestartTime);
  $StartTime = time;
  $RestartTime = $StartTime + MailScanner::Config::Value('restartevery');

  my $FirstCheck = MailScanner::Config::Value('firstcheck');
  MailScanner::Log::WarnLog("First Check must be set to MCP or spam")
    unless $FirstCheck =~ /mcp|spam/i;
  my $VirusBeforeSpamMCP = MailScanner::Config::Value('virusbeforespammcp');

  while (time>=$StartTime && time<$RestartTime && !$BayesRebuild) {
    $workarea->Clear();
    $0 = 'MailScanner: waiting for messages';
    print STDERR "Building a message batch to scan...\n" if $Debug;
    # Possibly restrict contents of batch to just $IDToScan
    $batch = new MailScanner::MessageBatch('normal', $IDToScan);
    $global::MS->{batch} = $batch; # So MailWatch can read the batch properties
    #print STDERR "Batch is $batch\n";

    # Print current size of batch.
    if ($Debug) {
      my $msgs = $batch->{messages};
      my $msgcount = scalar(keys %$msgs);
      my $msgss = ($msgcount==1)?'':'s';
      print STDERR "Have a batch of $msgcount message$msgss.\n";
    }

    # Bail out immediately if we are using the Sophos SAVI library and it
    # has been updated since the last batch. This has to be done after the
    # batch has been created since it may sit for minutes/hours in
    # MailScanner::MessageBatch::new.
    if (MailScanner::SweepViruses::SAVIUpgraded()) {
      MailScanner::Log::InfoLog("Sophos SAVI library has been " .
                                "updated, killing this child");
      last;
    }
    # # Also bail out if the ClamAV database has been upgraded
    # if (MailScanner::SweepViruses::ClamUpgraded()) {
    #   MailScanner::Log::InfoLog("ClamAV virus database has been " .
    #                             "updated, killing this child");
    #   last;
    # }

    # Also bail out if the LDAP configuration serial number has changed.
    if (MailScanner::Config::LDAPUpdated()) {
      MailScanner::Log::InfoLog("LDAP configuration has changed, " .
                                "killing this child");
      last;
    }

    # Check for SQL updates
    if (MailScanner::ConfigSQL::CheckForUpdate()) {
      MailScanner::Log::InfoLog("SQL configuration has changed, " .
                                "killing this child");
      last;
    }

    #$batch->print();

    # Archive untouched incoming messages to directories
    $batch->ArchiveToFilesystem();

    # Do this first as it is very cheap indeed. Reject unwanted messages.
    $batch->RejectMessages();

    # 20090730 Moved from below as it's a very early check.
    # Deliver all the messages we are not scanning at all,
    # and mark them for deletion.
    # Then purge the deleted messages from disk.
    $batch->DeliverUnscanned();
    $batch->RemoveDeletedMessages();

    # Have to do this very early as it's needed for MCP and spam bouncing
    $global::MS->{work}->BuildInDirs($batch);

    #
    ## 20090730 Start of virus-scanning code moved to before spam-scanning
    #

    # Extract all the attachments
    $batch->StartTiming('virus', 'Virus Scanning');
    # Moved upwards: $global::MS->{work}->BuildInDirs($batch);
    $0 = 'MailScanner: extracting attachments';
    $batch->Explode($Debug);

    # Report all the unparsable messages, but don't delete anything
    $batch->ReportBadMessages();

    # Build all the MIME entities helper structures
    $batch->CreateEntitiesHelpers();
    #$batch->PrintNumParts();
    #$batch->PrintFilenames();

    # Do the virus scanning
    $0 = 'MailScanner: virus scanning';
    $batch->VirusScan();
    #$batch->PrintInfections();
    $batch->StopTiming('virus', 'Virus Scanning');

    # Combine all the infection/problem reports
    $batch->CombineReports();

    # Find all the messages infected with "silent" viruses
    # This excludes all Spam-Viruses
    $batch->FindSilentAndNoisyInfections();

    # Quarantine all the infected attachments
    # Except for Spam-Viruses
    $0 = 'MailScanner: quarantining infections';
    $batch->QuarantineInfections();

    # Deliver all the "silent" infected messages
    # and mark them for deletion
    $0 = 'MailScanner: processing silent viruses';
    $batch->DeliverOrDeleteSilentExceptSpamViruses();

    #
    ## 20090730 End of virus-scanning code moved to before spam-scanning
    #


    # Yes I know this isn't elegant, but it's very short so it will do :-)
    my $UsingMCP = 0;
    $UsingMCP = 1 unless MailScanner::Config::IsSimpleValue('mcpchecks') &&
                        !MailScanner::Config::Value('mcpchecks');
    if ($FirstCheck =~ /mcp/i) {
      # Do the MCP checks
      if ($UsingMCP) {
        $0 = 'MailScanner: MCP checks';
        $batch->StartTiming('mcp', 'MCP Checks');
        $batch->MCPChecks();
        $batch->HandleMCP();
        $batch->HandleNonMCP();
        $batch->StopTiming('mcp', 'MCP Checks');
      }

      # Do the spam checks
      $0 = 'MailScanner: spam checks';
      $batch->StartTiming('spam', 'Spam Checks');
      $batch->SpamChecks();
      $batch->HandleSpam();
      $batch->HandleHam();
      $batch->StopTiming('spam', 'Spam Checks');
    } else {
      # Do the spam checks
      $0 = 'MailScanner: spam checks';
      $batch->StartTiming('spam', 'Spam Checks');
      $batch->SpamChecks();
      $batch->HandleSpam();
      $batch->HandleHam();
      $batch->StopTiming('spam', 'Spam Checks');

      # Do the MCP checks
      if ($UsingMCP) {
        $0 = 'MailScanner: MCP checks';
        $batch->StartTiming('mcp', 'MCP Checks');
        $batch->MCPChecks();
        $batch->HandleMCP();
        $batch->HandleNonMCP();
        $batch->StopTiming('mcp', 'MCP Checks');
      }
    }

    # Deliver all the messages we are not scanning at all,
    # and mark them for deletion.
    # Then purge the deleted messages from disk.
    $batch->DeliverUnscanned2();
    $batch->RemoveDeletedMessages();

    # 20090730 Moved all this code to before the spam-scanning, as it's
    # very fast these days anyway.
    ## Extract all the attachments
    #$batch->StartTiming('virus', 'Virus Scanning');
    ## Moved upwards: $global::MS->{work}->BuildInDirs($batch);
    #$0 = 'MailScanner: extracting attachments';
    #$batch->Explode($Debug);
    #
    ## Report all the unparsable messages, but don't delete anything
    #$batch->ReportBadMessages();
    #
    ## Build all the MIME entities helper structures
    #$batch->CreateEntitiesHelpers();
    ##$batch->PrintNumParts();
    ##$batch->PrintFilenames();
    #
    ## Do the virus scanning
    #$0 = 'MailScanner: virus scanning';
    #$batch->VirusScan();
    ##$batch->PrintInfections();
    #$batch->StopTiming('virus', 'Virus Scanning');

    # Add the virus stats to the SpamAssassin cache so we know
    # to keep this data for much longer.
    $batch->AddVirusInfoToCache();

    # Strip the HTML tags out of messages which the spam
    # settings have asked us to strip.
    # We want to do this to both messages for which the config
    # option says we should strip, and for messages for which
    # the spam actions say we should strip.
    $batch->StartTiming('virus_processing', 'Virus Processing');
    $0 = 'MailScanner: disarming and stripping HTML';
    $batch->StripHTML();
    $batch->DisarmHTML();

    #$batch->PrintInfectedSections();

    # 20090730 Moved up to be with the virus scanning code
    ## Combine all the infection/problem reports
    #$batch->CombineReports();

    # 20090730 Moved up to be with the virus scanning code
    ## Quarantine all the infected attachments
    #$0 = 'MailScanner: quarantining infections';
    #$batch->QuarantineInfections();

     # Quarantine all denial-of-service attempt
    $batch->QuarantineDOS();

    # Quarantine all the disarmed HTML and others
    $batch->QuarantineModifiedBody();

    # Remove any infected spam from the spam+mcp archives
    $batch->RemoveInfectedSpam();

    # 20090730 Moved up to be with the virus scanning code
    ## Find all the messages infected with "silent" viruses
    #$batch->FindSilentAndNoisyInfections();

    # Clean all the infections out of the messages
    $0 = 'MailScanner: cleaning messages';
    $batch->Clean();

    # Zip up all the attachments to compress them
    $0 = 'MailScanner: compressing attachments';
    $batch->ZipAttachments();
    # Encapsulate the messages into message/rfc822 attachments as needed
    $batch->Encapsulate();

    # Sign all external messages
    $batch->SignExternalMessage();

    # Sign all the uninfected messages
    $batch->SignUninfected();

    # Deliver all the uninfected messages
    # and mark them for deletion
    $batch->DeliverUninfected();

    # Delete cleaned messages that are from a local domain if we
    # aren't delivering cleaned messages from local domains,
    # by marking them for deletion. This will also stop them being
    # disinfected, which is fine. Also mark that they still need
    # relevant warnings/notices to be sent about them.
    # Then purge the deleted messages from disk.
    $batch->DeleteUnwantedCleaned();
    $batch->RemoveDeletedMessages();

    ## Find all the messages infected with "silent" viruses
    #$batch->FindSilentAndNoisyInfections();

    # 20090730 Moved up to be with the virus scanning code
    ## Deliver all the "silent" infected messages
    ## and mark them for deletion
    #$0 = 'MailScanner: processing silent viruses';
    #$batch->DeliverOrDeleteSilent();

    # Deliver all the cleaned messages
    # and mark them for deletion
    $0 = 'MailScanner: delivering cleaned messages';
    $batch->DeliverCleaned();
    $batch->RemoveDeletedMessages();

    # Warn all the senders of messages with any non-silent infections
    $0 = 'MailScanner: sending warnings';
    $batch->WarnSenders();

    # Warn all the notice recipents about all the viruses
    $batch->WarnLocalPostmaster();
    $batch->StopTiming('virus_processing', 'Virus Processing');

    # Disinfect all possible messages and deliver to original recipients,
    # and delete them as we go.
    $batch->StartTiming('disinfection', 'Disinfection');
    $0 = 'MailScanner: disinfecting macros';
    $batch->DisinfectAndDeliver();
    $batch->StopTiming('disinfection', 'Disinfection');

    # JKF 20090301 Anything without the "deleted" flag set has been
    # dropped from the batch. Anything else has been successfully dealt
    # with.
    $batch->ClearOutProcessedDatabase();

    # Do all the time and speed logging
    $batch->EndBatch();

    # Look up a configuration parameter as the last thing we do so that the
    # lookup operation can have side-effects such as logging stats about the
    # message.
    $0 = 'MailScanner: finishing batch';
    $batch->LastLookup();

    #print STDERR "\n\n3 times are $StartTime " . time . " $RestartTime\n\n\n";

    # Only do 1 batch if debugging
    last if $Debug;
  }

  $0 = 'MailScanner: child dying';
  # Destroy the incoming work dir
  $global::MS->{work}->Destroy();

  # Close down all the user's custom functions
  MailScanner::Config::EndCustomFunctions();

  # Tear down any LDAP connection
  MailScanner::Config::DisconnectLDAP();

  if ($BayesRebuild) {
    MailScanner::Log::InfoLog("MailScanner child dying after Bayes rebuild");
  } else {
    MailScanner::Log::InfoLog("MailScanner child dying of old age");
  }

  # Don't want to leave connections to 514/udp open
  MailScanner::Log::Stop();
}


#
# SIGHUP handler. Just make the child exit neatly and the parent
# farmer process will create a new one which will re-read the config.
#
sub ExitChild {
  my($sig) = @_; # Arg is signal name
  MailScanner::Log::InfoLog("MailScanner child caught a SIG%s", $sig);
  # Finish off any incoming queue file deletes that were pending
  MailScanner::SMDiskStore::DoPendingDeletes();
  # Delete SpamAssassin rebuild signaller
  unlink $MailScanner::SA::BayesRebuildStartLock
    if $MailScanner::SA::BayesRebuildStartLock;
  # Kill off any commercial virus scanner process groups that are still running
  kill -15, $MailScanner::SweepViruses::ScannerPID
    if $MailScanner::SweepViruses::ScannerPID;
  # Destroy the incoming work dir
  $global::MS->{work}->Destroy() if $global::MS && $global::MS->{work};
  # Decrement the counters in the Processing Attempts Database
  $global::MS->{batch}->DecrementProcDB()
    if $global::MS && $global::MS->{batch};
  # Close down all the user's custom functions
  MailScanner::Config::EndCustomFunctions();
  # Shut down the Processing Attempts Database
  $MailScanner::ProcDBH->disconnect() if $MailScanner::ProcDBH;
  # Close down logging neatly
  MailScanner::Log::Stop();
  exit 0;
}

sub KillChildren {
  my($child, @dirlist);

  $0 = 'MailScanner: killing children, bwahaha!';
  #print STDERR "Killing child processes...\n";
  if ($RunInForeground) {
    print STDOUT "Killing child processes ";
    print STDOUT join( '/', keys %Children);
  }
  kill 1, keys %Children;
  print STDOUT " and giving them time to die...\n" if $RunInForeground;

  sleep 3; # Give them time to die peacefully
  print STDOUT "Cleaning up..." if $RunInForeground;

  # Clean up after the dying processes in case they left a mess.
  foreach $child (keys %Children) {
    #push @dirlist, "$WorkDir/$child" if -d "$WorkDir/$child";
    rmtree("$WorkDir/$child", 0, 1) if -d "$WorkDir/$child";
  }
  print STDOUT "Done\n" if $RunInForeground;
}

#
# SIGKILL handler for parent process.
# HUP all the children, then keep working.
#
sub ReloadParent {
  my($sig) = @_; # Arg is the signal name

  print STDOUT "MailScanner parent caught a SIG$sig - reload\n"
    if $RunInForeground;

  KillChildren();

  print STDOUT "MailScanner reloaded.\n" if $RunInForeground;
}



#
# SIGTERM handler for parent process.
# HUP all the children, then commit suicide.
# Cannot log as no logging in the parent.
#
sub ExitParent {
  my($sig) = @_; # Arg is the signal name

  print STDOUT "MailScanner parent caught a SIG$sig\n" if $RunInForeground;

  KillChildren();

  print STDOUT "Exiting MailScanner - Bye.\n" if $RunInForeground;

  unlink $PidFile; # Ditch the pid file, thanks Res
  exit 0;
}


#
# Start logging
#
sub StartLogging {
  my($filename) = @_;

  # Create the syslog process name from stripping the conf filename down
  # to the basename without the extension.
  my $procname = $filename;
  $procname =~ s#^.*/##;
  $procname =~ s#\.conf$##;

  my $logbanner = "MailScanner Email Processor version " .
                  $MailScanner::Config::MailScannerVersion . " starting...";

  MailScanner::Log::Configure($logbanner, 'syslog'); #'stderr');

  # Need to know log facility *before* we have read the whole config file!
  my $facility = MailScanner::Config::QuickPeek($filename, 'syslogfacility');
  my $logsock  = MailScanner::Config::QuickPeek($filename, 'syslogsockettype');

  MailScanner::Log::Start($procname, $facility, $logsock);
}

#
# Function to harvest dead children
#
sub Reaper {
  1 until waitpid(-1, WNOHANG) == -1;
  $SIG{'CHLD'} = \&Reaper;  # loathe sysV
}

#
# Fork off and become a daemon so they get their shell back
#
sub ForkDaemon {
  my($debug) = @_;
  if ($debug) {
    print STDERR "In Debugging mode, not forking...\n";
    # Get current debugging flag, and invert it:
    #my $current = config MIME::ToolUtils 'DEBUGGING';
    #config MIME::ToolUtils DEBUGGING => !$current;
  } elsif ($RunInForeground) {
    # PERT-BBY we don't close STDXX neither fork() nor setsid()
    #          if we want to run in the foreground
    print STDOUT "MailScanner $MailScanner::Config::MailScannerVersion " .
                 "starting in foreground mode - pid is [$$]\n";
  } else {
    $SIG{'CHLD'} = \&Reaper;
    if (fork==0) {
      # This child's parent is perl
      #print STDERR "In the child\n";
      # Close i/o streams to break connection with tty
      close(STDIN);
      close(STDOUT);
      close(STDERR);
      # Re-open the stdin, stdout and stderr file descriptors for
      # sendmail's benefit. Should stop it squawking!
      open(STDIN,  "</dev/null");
      open(STDOUT, ">/dev/null");
      open(STDERR, ">/dev/null");

      fork && exit 0;
      # This new grand-child's parent is init
      #print STDERR "In the grand-child\n";
      $SIG{'CHLD'} = 'DEFAULT';
      # Auto-reap children
      # Causes problems on some OS's when wait is called
      #$SIG{'CHLD'} = 'IGNORE';
      setsid();
    } else {
      #print STDERR "In the parent\n";
      wait; # Ensure child has exited
      exit 0;
    }
    # This was the old simple code in the 2nd half of the if statement
    #fork && exit;
    #setsid();
  }
}


#
# Set the current UID and GID if they are non-zero
#
#sub SetUidGid {
#  my($uid, $gid) = @_;
#
#  if ($gid) { # Only do this if setting to non-root
#    #print STDERR "Setting GID to $gid\n";
#    MailScanner::Log::InfoLog("MailScanner setting GID to $gname ($gid)");
#    POSIX::setgid($gid) or MailScanner::Log::DieLog("Can't set GID $gid");
#  }
#  if ($uid) { # Only do this if setting to non-root
#    #print STDERR "Setting UID to $uid\n";
#    MailScanner::Log::InfoLog("MailScanner setting UID to $uname ($uid)");
#    POSIX::setuid($uid) or MailScanner::Log::DieLog("Can't set UID $uid");
#  }
#  $) = $(;
#  $> = $<;
#}

sub SetUidGid {
  my($uid, $gid, $qgid, $igid) = @_;

  if ($gid) { # Only do this if setting to non-root
    #print STDERR "Setting GID to $gid\n";
    MailScanner::Log::InfoLog("MailScanner setting GID to $gname ($gid)");
    # assign in parallel to avoid tripping taint mode on
    ($(, $)) = ($gid, $gid);
    $( == $gid && $) == $gid or die "Can't set GID $gid";
    # We add 2 copies of the $gid as the second one is ignored by BSD!
    $) = "$gid $gid $qgid $igid"; # Set the extra group memberships we need
  } else {
    $) = $(;
  }
  if ($uid) { # Only do this if setting to non-root
    #print STDERR "Setting UID to $uid\n";
    MailScanner::Log::InfoLog("MailScanner setting UID to $uname ($uid)");
    # assign in parallel to avoid tripping taint mode on
    ($<, $>) = ($uid, $uid);
    $< == $uid && $> == $uid or die "Can't set UID $uid";
  } else {
    $> = $<;
  }
}


#
# Check the home directory of the user exists and is writable
#
sub CheckHomeDir {
  my $home = (getpwuid($<))[7];

  MailScanner::Log::WarnLog("User's home directory $home does not exist")
    unless -d $home;
  unless (-w $home ||
          (MailScanner::Config::IsSimpleValue('usespamassassin') &&
           !MailScanner::Config::Value('usespamassassin'))) {
    MailScanner::Log::WarnLog("User's home directory $home is not writable");
    MailScanner::Log::WarnLog("You need to set the \"SpamAssassin User " .
      "State Dir\" to a directory that the \"Run As User\" can write to");
  }
}

# This is now obsolete as no references to SystemDefs exist any more.
##
## Check all of the programs whose locations are set in SystemDefs.pl
## as some of them might be wrong, which will cause it to fail very
## quietly.
##
#sub CheckSystemDefs {
#  my($prog, $errors);
#  $errors = 0;
#  foreach $prog ($global::rm, $global::cp, $global::cat, $global::sed) {
#    next if -x $prog;
#    MailScanner::Log::WarnLog("The location of %s in SystemDefs.pm is wrong",
#                              $prog);
#    $errors++;
#  }
#  MailScanner::Log::DieLog("Aborting due to SystemDefs.pm errors") if $errors;
#}


#
# Check the versions of the MIME and SpamAssassin modules
#
sub CheckModuleVersions {
  my($module_version);

  # Check the MIME-tools version
  MailScanner::Log::DieLog("FATAL: Newer MIME::Tools module needed: " .
                           "MIME::Tools is only %s -- 5.412 required",
                           $MIME::Tools::VERSION)
    if defined $MIME::Tools::VERSION &&
       $MIME::Tools::VERSION<"5.412";


  # And check the SpamAssassin version
  MailScanner::Log::DieLog("FATAL: Newer Mail::SpamAssassin module needed: " .
                           "Mail::SpamAssassin is only %s -- 2.1 required",
                           $Mail::SpamAssassin::VERSION)
    if defined $Mail::SpamAssassin::VERSION &&
       $Mail::SpamAssassin::VERSION<"2.1";
}


#
# Check the incoming and (default) outgoing queues are on the same filesystem.
# MailScanner cannot work fast enough if they are in different filesystems.
#
#
# Check the incoming and outgoing queues are on the same device.
# Can only check the default outgoing queue, but that will be
# enough for most users.
#
sub CheckQueuesAreTogether {
  my($indevice, $outdevice, @instat, @outstat);
  my($inuid, $outuid, $ingrp, $outgrp);

  my @inqdirs;
  my $outqdir = MailScanner::Config::Value('outqueuedir');
  push @inqdirs, @{MailScanner::Config::Value('inqueuedir')};
  #print STDERR "Queues are \"" . join('","',@inqdirs) . "\"\n";

  #MailScanner::Log::WarnLog("Queuedir is %s", $outqdir);
  #Outq cannot be split: MailScanner::Sendmail::CheckQueueIsFlat($outqdir);
  chdir($outqdir); # This should be the default
  @outstat = stat('.');
  ($outdevice, $outuid, $outgrp) = @outstat[0,4,5];
  MailScanner::Log::DieLog("%s is not owned by user %d !", $outqdir, $uid)
    if $uid && ($outuid != $uid);

  my($inqdir);
  foreach $inqdir (@inqdirs) {

    # FIXME: $inqdir is somehow tained: work out why!
    $inqdir =~ /(.*)/;
    $inqdir = $1;

    #MailScanner::Log::WarnLog("Inq %s", $inqdir);
    MailScanner::Sendmail::CheckQueueIsFlat($inqdir);
    chdir($inqdir);
    @instat = stat('.');
    ($indevice, $inuid, $ingrp) = @instat[0,4,5];

    MailScanner::Log::DieLog("%s & %s must be on the same filesystem/" .
                             "partition!", $inqdir, $outqdir)
      unless $indevice == $outdevice;
    MailScanner::Log::DieLog("%s is not owned by user %d !", $inqdir, $uid)
      if $uid && ($inuid != $uid);
  }
}


#
# Create and write a PID file for a given process id
#
sub WritePIDFile {
  my($process) = @_;

  my $pidfh = new FileHandle;
  $pidfh->open(">$PidFile")
    or MailScanner::Log::WarnLog("Cannot write pid file %s, %s", $PidFile, $!);
  print $pidfh "$process\n";
  $pidfh->close();
}

##
## Delete the PID file for a given process id
##
#sub DeletePIDFile {
#  my($process) = @_;
#  unlink("$PidDir/MailScanner.$process");
#}

#
# Dump the contents of the "Processing Attempts Database"
sub DumpProcessingDatabase {
  my($filename, $minimum) = @_;

  unless (eval "require DBD::SQLite") {
    MailScanner::Log::WarnLog("WARNING: You are trying to use the Processing Attempts Database but your DBI and/or DBD::SQLite Perl modules are not properly installed!");
    return;
  }

  my $DBH = DBI->connect("dbi:SQLite:$filename",
                         "","",{PrintError=>0,InactiveDestroy=>1});

  # Do they just want a dump of the database table?
  if ($DBH) {
    my $currenttable = '';
    my $rows = $DBH->selectall_arrayref(
      "SELECT id,count,nexttime FROM processing WHERE count>$minimum ORDER BY nexttime DESC",
      { Slice => {} });
    foreach my $row (@$rows) {
      my $now = localtime($row->{nexttime});
      $currenttable .= $row->{count}    . "\t" .
                       $row->{id}       . "\t" .
                       $now             . "\n";
    }
    if ($currenttable) {
      my $count = @$rows;
      print "Currently being processed:\n\n";
      print "Number of messages: $count\n";
      print "Tries\tMessage\tNext Try At\n=====\t=======\t===========\n";
      print $currenttable;
    }

    my $archivetable = '';
    my $rows = $DBH->selectall_arrayref(
      "SELECT id,count,nexttime FROM archive WHERE count>$minimum ORDER BY nexttime DESC",
      { Slice => {} });
    foreach my $row (@$rows) {
      my $now = localtime($row->{nexttime});
      $archivetable .= $row->{count}    . "\t" .
                       $row->{id}       . "\t" .
                       $now             . "\n";
    }
    if ($archivetable) {
      my $count = @$rows;
      print "\n\n" if $currenttable; # Separator between tables
      print "Archive:\n\n";
      print "Number of messages: $count\n";
      print "Tries\tMessage\tLast Tried\n=====\t=======\t==========\n";
      print $archivetable;
    }
    $DBH->disconnect;
    return;
  }
}

#
# Create the "Processing Attempts Database"
#
sub CreateProcessingDatabase {
  my($WantLint) = @_;

  # Master switch!
  return unless MailScanner::Config::Value('procdbattempts');

  unless (eval "require DBD::SQLite") {
    MailScanner::Log::WarnLog("WARNING: You are trying to use the Processing Attempts Database but your DBI and/or DBD::SQLite Perl modules are not properly installed!");
  }

  $MailScanner::ProcDBName = MailScanner::Config::Value("procdbname");
  if ($WantLint) {
    unless ($MailScanner::ProcDBName) {
      MailScanner::Log::WarnLog("WARNING: Your Processing Attempts Database name is not set!");
      return;
    }
    unless (eval { $MailScanner::ProcDBH = DBI->connect("dbi:SQLite:$MailScanner::ProcDBName","","",{PrintError=>0,InactiveDestroy=>1}); }) {
      MailScanner::Log::WarnLog("ERROR: Could not connect to SQLite database %s, either I cannot write to that location or your SQLite installation is screwed.", $MailScanner::ProcDBName);
      return;
    }
  } else {
    $MailScanner::ProcDBH = DBI->connect(
                            "dbi:SQLite:$MailScanner::ProcDBName",
                            "","",{PrintError=>0,InactiveDestroy=>1});
  }

  if ($MailScanner::ProcDBH) {
    MailScanner::Log::InfoLog("Connected to Processing Attempts Database");
    # Rebuild all the tables and indexes. The PrintError=>0 will make it
    # fail quietly if they already exist.
    # Speed up writes at the cost of integrity. It's only temp data anyway.
    $MailScanner::ProcDBH->do("PRAGMA default_synchronous = OFF");
    $MailScanner::ProcDBH->do("CREATE TABLE processing (id TEXT, count INT, nexttime INT)");
    $MailScanner::ProcDBH->do("CREATE UNIQUE INDEX id_uniq ON processing(id)");
    $MailScanner::ProcDBH->do("CREATE TABLE archive (id TEXT, count INT, nexttime INT)");
    print STDERR "Created Processing Attempts Database successfully\n"
      if $WantLint;                                      
    my $rows = $MailScanner::ProcDBH->selectrow_array("SELECT COUNT(*) FROM processing");
    print STDERR "There " . ($rows==1?'is':'are') . " $rows message" . ($rows==1?'':'s') . " in the Processing Attempts Database\n" if $WantLint;
    MailScanner::Log::InfoLog("Found %d messages in the Processing Attempts Database", $rows) unless $WantLint;

    # Prepare all the SQL statements we will need
    $MailScanner::SthSelectId      = $MailScanner::ProcDBH->prepare(
      "SELECT id,count,nexttime FROM processing WHERE (id=?)");
    $MailScanner::SthDeleteId      = $MailScanner::ProcDBH->prepare(
      "DELETE FROM processing WHERE (id=?)");
    $MailScanner::SthInsertArchive = $MailScanner::ProcDBH->prepare(
      "INSERT INTO archive (id,count,nexttime) VALUES (?,?,?)");
    $MailScanner::SthIncrementId   = $MailScanner::ProcDBH->prepare(
      "UPDATE processing SET count=count+1, nexttime=? WHERE (id=?)");
    $MailScanner::SthInsertProc    = $MailScanner::ProcDBH->prepare(
      "INSERT INTO processing (id,count,nexttime) VALUES (?,?,?)");
    $MailScanner::SthSelectRows    = $MailScanner::ProcDBH->prepare(
      "SELECT id,count,nexttime FROM processing WHERE (id=?)");
    $MailScanner::SthSelectCount   = $MailScanner::ProcDBH->prepare(
      "SELECT count FROM processing WHERE (id=?)");
    $MailScanner::SthDecrementId   = $MailScanner::ProcDBH->prepare(
      "UPDATE processing SET count=count-1 WHERE (id=?)");
    unless ($MailScanner::SthSelectId      && $MailScanner::SthDeleteId    &&
            $MailScanner::SthInsertArchive && $MailScanner::SthIncrementId &&
            $MailScanner::SthInsertProc    && $MailScanner::SthSelectRows  &&
            $MailScanner::SthSelectCount   && $MailScanner::SthDecrementId) {
      MailScanner::Log::WarnLog("Preparing SQL statements for processing-" .
                                "messages database failed!");
    }

  } else {
    MailScanner::Log::WarnLog("Could not create Processing Attempts Database \"%s\"", $MailScanner::ProcDBName);
  }

}

1;
