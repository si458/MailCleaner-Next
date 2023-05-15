#!/usr/bin/env perl
#
#   Mailcleaner - SMTP Antivirus/Antispam Gateway
#   Copyright (C) 2004 Olivier Diserens <olivier@diserens.ch>
#   Copyright (C) 2023 John Mertz <git@john.me.tz>
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
#
#   This script will dump the mysql configuration file from the configuration
#   setting found in the database.
#
#   Usage:
#           dump_mysql_config.pl

use v5.36;
use strict;
use warnings;
use utf8;

if ($0 =~ m/(\S*)\/\S+.pl$/) {
    my $path = $1."/../lib";
    unshift (@INC, $path);
}

our $DEBUG = 1;

my %config = readConfig("/etc/mailcleaner.conf");

## added 10 for migration ease
$config{'__MASTERID__'} = ($config{'HOSTID'} * 2) - 1 + 10;
$config{'__SLAVEID__'} = $config{'HOSTID'} * 2 + 10;

## Avoid having unsychronized database when starting a new VA
my $FIRSTUPDATE_FLAG_RAN="$config{'VARDIR'}/run/configurator/updater4mc-ran";
if (-e $FIRSTUPDATE_FLAG_RAN){
    $config{'__BINARY_LOG_KEEP__'} = 21;
} else {
    $config{'__BINARY_LOG_KEEP__'} = 0;
}

my $lasterror = "";

dump_mysql_file($config{'SRCDIR'},'master') or fatal_error("CANNOTDUMPMYSQLFILE", $lasterror);
dump_mysql_file($config{'SRCDIR'},'slave') or fatal_error("CANNOTDUMPMYSQLFILE", $lasterror);

print "DUMPSUCCESSFUL";

#############################
sub dump_mysql_file($srcdir,$stage)
{
    my $template_file = $srcdir."/etc/mysql/my_$stage.cnf_template";
    my $target_file = $srcdir."/etc/mysql/my_$stage.cnf";

    my ($TEMPLATE, $TARGET);
    if ( !open($TEMPLATE, '<', $template_file) ) {
        $lasterror = "Cannot open template file: $template_file";
        return 0;
    }
    if ( !open($TARGET, '>', $target_file) ) {
        $lasterror = "Cannot open target file: $target_file";
        close $template_file;
        return 0;
    }

    while(<$TEMPLATE>) {
        my $line = $_;

        $line =~ s/__VARDIR__/$config{'VARDIR'}/g;
        $line =~ s/__SRCDIR__/$config{'SRCDIR'}/g;

        foreach my $key (keys %config) {
            $line =~ s/$key/$config{$key}/g;
        }

        print $TARGET $line;
    }

    close $TEMPLATE;
    close $TARGET;

    return 1;
}

#############################
sub fatal_error($msg,$full)
{
    print $msg . ($DEBUG ? "\nFull information: $full \n" : "\n");
}

#############################
sub print_usage
{
    print "Bad usage: dump_mysql_config.pl\n";
}

#############################
sub readConfig($configfile)
{
    my %config;
    my ($var, $value);

    open (my $CONFIG, '<', $configfile) or die "Cannot open $configfile: $!\n";
    while (<$CONFIG>) {
        chomp;              # no newline
        s/#.*$//;           # no comments
        s/^\*.*$//;         # no comments
        s/;.*$//;           # no comments
        s/^\s+//;           # no leading white
        s/\s+$//;           # no trailing white
        next unless length; # anything left?
        my ($var, $value) = split(/\s*=\s*/, $_, 2);
        $config{$var} = $value;
    }
    close $CONFIG;
    return %config;
}
