#!/bin/bash

. variables.sh

# Setup test server
echo "## Setting up test pg server"
/usr/lib/postgresql/9.2/bin/initdb ${DEMO}

cp postgresql.conf ${DEMO}/postgresql.conf

#### Update pg_hba.conf ####
(
cat <<-DEMO
	local   replication     $USER                                trust
	host    replication     $USER        127.0.0.1/32            trust
	host    replication     $USER        ::1/128                 trust
	host    all     $USER        127.0.0.1/32            trust
DEMO
)  >> ${DEMO}/pg_hba.conf

$PGCTL -D ${DEMO} start > ${DEMO}.log 2>&1
sleep 3

# Put some data in there
$PSQL -p $PORT -U $USER postgres -c "CREATE DATABASE pgbench"

/usr/lib/postgresql/9.2/bin/pgbench -i -s 1 pgbench -h /tmp -p ${PORT}

# Set up barman backup directory
echo "Setting up barman"
mkdir -p $BACKUPDIR
sudo mkdir -p $LOGDIR
sudo chown $USER.$USER $LOGDIR

# Set up conf file
(
cat <<-BARMANCONF
[barman]
; Main directory
barman_home = $BARMANHOME

; System user
barman_user = $USER

; Log location
log_file = $LOGDIR/barman.log

; Default compression level: possible values are None (default), bzip2, gzip or custom
;compression = gzip

; Pre/post backup hook scripts
;pre_backup_script = env | grep ^BARMAN
;post_backup_script = env | grep ^BARMAN

; Directory of configuration files. Place your sections in separate files with .conf extension
; For example place the 'main' server section in /etc/barman.d/main.conf
;configuration_files_directory: /etc/barman.d

; 'main' PostgreSQL Server configuration
[main]
; Human readable description
description =  "Main PostgreSQL Database"

; SSH options
ssh_command = ssh $USER@localhost

; PostgreSQL connection string
conninfo = host=localhost user=$USER port=$PORT dbname=pgbench

BARMANCONF
) > ~/.barman.conf

# Verify that we have access to tools
echo "## Checking config"
barman show-server main
barman check main

INCOMING=$(barman show-server main | grep incoming_wals_directory | awk '{print $2}')

echo $INCOMING

# Edit postgresql.conf

(
cat <<-PGCEDIT
wal_level = 'hot_standby' # For PostgreSQL >= 9.0
archive_mode = on
archive_command = 'rsync -a %p $USER@localhost:$INCOMING/%f'
PGCEDIT
) >> ${DEMO}/postgresql.conf

# Restart postgres to have changes take effect
$PGCTL -D ${DEMO} restart

echo "CREATING BACKUP"
# Clone our test database
barman backup main
echo "DONE backing up"

# Grab the latest OK backup and recover to create a replica
RESTORE=$(barman list-backup main|awk '{print $2}')

# Set up a replica
# Now untar this into a subdir
echo "Recovering $RESTORE"
barman recover main $RESTORE ${DEMO2}

( 
cat <<-NEWPORT
port=$PORT2
NEWPORT
) >> ${DEMO2}/postgresql.conf

## add a recovery.conf
(
cat <<-RECOV
standby_mode = 'on'
primary_conninfo = 'host=localhost port=$PORT dbname=pgbench'
RECOV
) >> ${DEMO2}/recovery.conf

$PGCTL -D ${DEMO2} start > ${DEMO2}.log 2>&1

