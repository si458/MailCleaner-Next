#!/usr/bin/perl -w
#
#   Mailcleaner - SMTP Antivirus/Antispam Gateway
#   Copyright (C) 2004 Olivier Diserens <olivier@diserens.ch>
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

package          model::InLine::YesNoDialog ;
require          Exporter;
use Term::ReadKey;

our @ISA        = qw(Exporter);
our @EXPORT     = qw(build display);
our $VERSION    = 1.0;

sub get {

  my $text = '';
  my $default = '';

  my $this =  {
    text => $text,
    default => $default
  };

  bless $this, "model::InLine::YesNoDialog";
  return $this;
}

sub build {
  my $this = shift;
  my $text = shift;
  my $default = shift;

  $this->{text} = $text;
  $this->{default} = $this->getYesNo($default);

  return $this;
}

sub display {
  my $this = shift;

  if (!$this->{default}) {
   $this->{default} = '';
  }
  print $this->{text}."\n";
  print "Enter \"y\" or \"n\" [".$this->{default}."]: ";
  ReadMode 'normal';
  my $result = ReadLine(0);
  chomp $result;
  if ( $result eq "") {
   $result = $this->{default};
  }
  return $this->getYesNo($result);
}

sub clear {
  my $this = shift;

  system('clear');
}

sub getYesNo {
  my $this = shift;
  my $value = shift;

  if ($value =~ m/^(y|yes)$/i) {
   return 'yes';
  }

  return 'no';
}

1;
