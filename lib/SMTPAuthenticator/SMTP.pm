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

package          SMTPAuthenticator::SMTP;
require          Exporter;
use              Net::SMTP_auth;
use strict;

our @ISA        = qw(Exporter);
our @EXPORT     = qw(create authenticate);
our $VERSION    = 1.0;


sub create {
   my $server = shift;
   my $port = shift;
   my $params = shift;

   if ($port < 1 ) {
     $port = 25;
   }
   my $this = {
           error_text => "",
           error_code => -1,
           server => $server,
           port => $port
         };

  bless $this, "SMTPAuthenticator::SMTP";
  return $this;
}

sub authenticate {
  my $this = shift;
  my $username = shift;
  my $password = shift;

  my $smtp;
  unless ($smtp = Net::SMTP_auth->new($this->{server}.":".$this->{port})) {
  	 $this->{'error_code'} = 0;
  	 $this->{'error_text'} = 'Cannot connect to server: '.$this->{server}.' on port '.$this->{port};
     return 0;
  }

  my $auth_type = 'LOGIN';
  my @auths = split('\s', $smtp->auth_types());
  if (@auths) {
    $auth_type = shift(@auths);
  }

  if ($smtp->auth($auth_type, $username, $password)) {
  	$this->{'error_code'} = 0;
  	$this->{'error_text'} = '';
  	$smtp->quit();
  	return 1;
  }
  $this->{'error_code'} = 1;
  $this->{'error_text'} = 'Authentication failed';
  $smtp->quit();
  return 0;
}
1;
