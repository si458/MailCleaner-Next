#!/usr/bin/env bash
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
#   This script will resync the configuration database

function usage() {
    echo "usage: $0 [-F] [MHOST MPASS]
    -F     Force resync. Ignore sync test
    -C     Run as cron. Sends STDOUT to $LOGDIR
    MHOST  master hostname
    MPASS  master password"
    exit
}

function check_status() {
    echo "Checking slave status..."

    STATUS=$(echo 'show slave status\G' | /usr/mailcleaner/bin/mc_mysql -s)
    if grep -vq "Slave_SQL_Running: Yes" <<< $(echo $STATUS); then
        echo "Slave_SQL_Running failed"
        RUN=1
    elif grep -vq "Slave_IO_Running: Yes" <<< $(echo $STATUS); then
        echo "Slave_IO_Running failed"
        RUN=1
    fi
}

LOGDIR="/var/mailcleaner/log/mailcleaner/resync"
LOCKFILE='/var/mailcleaner/spool/tmp/resync_db'
MHOST=''
MPASS=''

if [ ! -d $LOGDIR ]; then
    mkdir -p $LOGDIR
fi

for var in "$@"; do
    if [[ $var == '-F' ]]; then
        RUN=1
    elif [[ $var == '-C' ]]; then
        exec 1>>"$LOGDIR/resync.log"
        exec 2>"/dev/null"
        # If failed on previous cron run, this file will exist with a count of failures
        if [ -e $LOCKFILE ]; then
            # If it has failed 6 times stop trying
            if test `find "/var/mailcleaner/spool/tmp/resync_db" -mmin +230`; then
                echo "Last try is more than 4 hours ago. Trying to fix"
                rm "/var/mailcleaner/spool/tmp/resync_db"
                RUN=1
            else
                echo "Last try is too recent. Exiting"
                exit
            fi
        fi
    # First default is master host
    elif [[ $MHOST == '' ]]; then
        MHOST=$var
    # Second default is master pass
    elif [[ $MPASS == '' ]]; then
        MPASS=$var
    # If both of the above are set, this var is excess
    else
        echo "Invalid or excess option '$var'."
        usage()
    fi
done

VARDIR=`grep 'VARDIR' /etc/mailcleaner.conf | cut -d ' ' -f3`
if [ "VARDIR" = "" ]; then
    VARDIR=/var/mailcleaner
fi
SRCDIR=`grep 'SRCDIR' /etc/mailcleaner.conf | cut -d ' ' -f3`
if [ "SRCDIR" = "" ]; then
    SRCDIR=/var/mailcleaner
fi

echo "starting slave db..."
$SRCDIR/etc/init.d/mysql_slave start
sleep 5

check_status
if [[ $RUN != 1 ]]; then
    echo "DBs are already in sync. Run with -F to force resync anyways."
    exit
else
    # Clear RUN as it will be used for the post-sync test result as well
    RUN=0
    echo "Running resync..."
fi

# Resync

MYMAILCLEANERPWD=`grep 'MYMAILCLEANERPWD' /etc/mailcleaner.conf | cut -d ' ' -f3`
echo "select hostname, password from master;" | $SRCDIR/bin/mc_mysql -s mc_config | grep -v 'password' | tr -t '[:blank:]' ':' > /var/tmp/master.conf

if [ "$MHOST" != "" ]; then
    export MHOST
else
    export MHOST=`cat /var/tmp/master.conf | cut -d':' -f1`
fi
if [ "$MPASS" != "" ]; then
    export MPASS
else
    export MPASS=`cat /var/tmp/master.conf | cut -d':' -f2`
fi

/usr/bin/mariadb-dump -S$VARDIR/run/mysql_slave/mysqld.sock -umailcleaner -p$MYMAILCLEANERPWD mc_config update_patch > /var/tmp/updates.sql

/usr/bin/mariadb-dump -h $MHOST -umailcleaner -p$MPASS --master-data mc_config > /var/tmp/master.sql
$SRCDIR/etc/init.d/mysql_slave stop
sleep 2
rm $VARDIR/spool/mysql_slave/master.info  >/dev/null 2>&1
rm $VARDIR/spool/mysql_slave/mysqld-relay*  >/dev/null 2>&1
rm $VARDIR/spool/mysql_slave/relay-log.info >/dev/null 2>&1
$SRCDIR/etc/init.d/mysql_slave start nopass
sleep 5
echo "STOP SLAVE;" | $SRCDIR/bin/mc_mysql -s
sleep 2
rm $VARDIR/spool/mysql_slave/master.info >/dev/null 2>&1
rm $VARDIR/spool/mysql_slave/mysqld-relay* >/dev/null 2>&1
rm $VARDIR/spool/mysql_slave/relay-log.info >/dev/null 2>&1

$SRCDIR/bin/mc_mysql -s mc_config < /var/tmp/master.sql

sleep 2
echo "CHANGE MASTER TO master_host='$MHOST', master_user='mailcleaner', master_password='$MPASS'; " | $SRCDIR/bin/mc_mysql -s
$SRCDIR/bin/mc_mysql -s mc_config < /var/tmp/master.sql
echo "START SLAVE;" | $SRCDIR/bin/mc_mysql -s
sleep 5

$SRCDIR/etc/init.d/mysql_slave restart
sleep 5
$SRCDIR/bin/mc_mysql -s mc_config < /var/tmp/updates.sql

# Run the check again and record results
check_status
if [[ $RUN != 1 ]]; then
    echo "Resync successful."
    # If there were previous failures, remove that flag file
    if [[ -e $LOCKFILE ]]; then
        echo "Removing lockfile"
        rm $LOCKFILE
    fi
fi
