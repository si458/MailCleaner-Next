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
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

package SMTPAuthenticator::IMAP;

use v5.36;
use strict;
use warnings;
use utf8;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(create authenticate);
our $VERSION = 1.0;

sub create($server,$port,$params)
{
    my $use_ssl = 0;
    if ($params =~ /^[01]$/) {
        $use_ssl = $params;
    }

    if ($port < 1 ) {
        $port = 143;
    }
    my $self = {
        error_text => "",
        error_code => -1,
        server => $server,
        port => $port,
        use_ssl => $use_ssl
    };

    bless $self, "SMTPAuthenticator::IMAP";
    return $self;
}

sub authenticate($self,$username,$password)
{
    my $imap;
    if ($self->{use_ssl}) {
        require Net::IMAP::Simple::SSL;
        $imap = new Net::IMAP::Simple::SSL($self->{server}.":".$self->{port});
    } else {
        require Net::IMAP::Simple;
        $imap = new Net::IMAP::Simple($self->{server}.":".$self->{port});
    }

    if ($imap && $imap->login( $username, $password )) {
        $imap->quit;
        $self->{'error_code'} = 0;
        $self->{'error_text'} = $imap->errstr;
        return 1;
    }

    if (!$imap) {
        $self->{'error_text'} = "Could not connect to ".$self->{server}.":".$self->{port}." ssl:".$self->{use_ssl};
    } else {
        $self->{'error_text'} = $imap->errstr;
    }
    $self->{'error_code'} = 1;
    return 0;
}

1;
