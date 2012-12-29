#!/bin/bash

. variables.sh

# Setup test server
echo "## Setting up test pg server"
/usr/lib/postgresql/9.2/bin/initdb ${DEMO}

cp postgresql.conf ${DEMO}/postgresql.conf
#### Update postgresql.conf ####
(
cat <<-PGCUPDATE
archive_command = 'cp "%p" $HOMEDIR/wal_archive/"%f"' # For ARCLOG variable in pg_rman
PGCUPDATE
) >> ${DEMO}/postgresql.conf

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

# Set up pg_rman
echo "Setting up barman"
mkdir -p $RMANHOMEDIR
mkdir -p $ARCDIR
sudo mkdir -p $LOGDIR
sudo chown $USER.$USER $LOGDIR

# Set up pg_rman
pg_rman init -B $RMANHOMEDIR

# Set up conf file
(
cat <<-BARMANCONF
ARCLOG_PATH = $ARCDIR
SRVLOG_PATH = $HOMEDIR/${DEMO}/pg_log

BACKUP_MODE = F
COMPRESS_DATA = YES
KEEP_ARCLOG_FILES = 10
KEEP_ARCLOG_DAYS = 10
KEEP_DATA_GENERATIONS = 3
KEEP_DATA_DAYS = 120
KEEP_SRVLOG_FILES = 10
KEEP_SRVLOG_DAYS = 10
BARMANCONF
) > $RMANHOMEDIR/pg_rman.ini

THISMONTH=$(date +%Y-%m)

pg_rman -B $RMANHOMEDIR show $THISMONTH

pg_rman -B $RMANHOMEDIR backup --backup-mode=full --with-serverlog -D $HOMEDIR/${DEMO} --dbname=postgres --port $PORT --host localhost

pg_rman -B $RMANHOMEDIR validate

pg_rman -B $RMANHOMEDIR show $THISMONTH

# Set up a standby
echo "## Set up standby"
pg_rman -B $RMANHOMEDIR restore -D $HOMEDIR/${DEMO2}

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

