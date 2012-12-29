#!/bin/bash

. variables.sh

# Verify that we have access to tools

echo "# Starting"
echo "## Running sanity check"
sanity-check.sh

if [ $? -ne 0 ]; then
    echo "Can't run sanity check. Check PATH for sanity-check.sh. Quitting."
    exit 1
fi

mkdir -p hot_standby
mkdir -p wal_archive

/usr/lib/postgresql/9.2/bin/initdb ${DEMO}

cp postgresql.conf ${DEMO}/postgresql.conf
mkdir -p ${DEMO}/pg_log
(
cat <<-PGCONF
archive_command = '$OMNIPATH/omnipitr-archive -l $LOGPATH/omnipitr-^Y^m^d.log -s $STATEPATH/state -dr gzip=$TESTPATH/wal_archive -db $TMPPATH/dstbackup -t /tmp/omnipitr/ -v "%p"'
archive_timeout = 60
PGCONF
) >> ${DEMO}/postgresql.conf

#### Update pg_hba.conf ####
(
cat <<-DEMO
	local   replication     $USER                                trust
	host    replication     $USER        127.0.0.1/32            trust
	host    replication     $USER        ::1/128                 trust
DEMO
)  >> ${DEMO}/pg_hba.conf

$PGCTL -D ${DEMO} start > ${DEMO}.log 2>&1

sleep 3

$PSQL -p $PORT -U $USER postgres -c "CREATE DATABASE pgbench"

/usr/lib/postgresql/9.2/bin/pgbench -i -s 1 pgbench -h /tmp -p ${PORT}

echo "CLONING"
# Clone our test database
omnipitr-backup-master -p $PORT -h /tmp -D test -l $LOGPATH/omnipitr-^Y^m^d.log -x $TMPPATH/dstbackup -dr gzip=$TESTPATH/hot_standby -t $TMPPATH/omnipitr/ --pid-file $STATEPATH/backup-master.pid -v

echo "DONE backing up"

# Set up a replica
# Now untar this into a subdir
umask 077
mkdir test2
cd test2
tar --strip-components=1 -zxf  $TESTPATH/hot_standby/$HOSTNAME-data*
tar --strip-components=1 -zxvf $TESTPATH/hot_standby/$HOSTNAME-xlog*

cd ..

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
restore_command = '$OMNIPATH/omnipitr-restore -l $LOGPATH/omnipitr-^Y^m^d.log -s gzip=$TESTPATH/wal_archive -f $TESTPATH/finish.recovery -r -p $TESTPATH/pause.removal -v -t $TMPPATH/omnipitr/ -w 900 %f %p'
RECOV
) >> ${DEMO2}/recovery.conf

$PGCTL -D ${DEMO2} start > ${DEMO2}.log 2>&1

