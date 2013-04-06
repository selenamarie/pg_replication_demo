#!/bin/bash

. variables.sh

mkdir /tmp/wal_archive

/usr/lib/postgresql/9.2/bin/initdb ${DEMO}

cp postgresql.conf ${DEMO}/postgresql.conf

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

(
cat <<-REPLICA
slave_config = $HOMEDIR/wal-slave.ini
primary_conninfo = host=localhost port=$PORT user=$USER
REPLICA
) >> wal-master.ini

(
cat <<-SLAVEDATA
slave_data = $HOMEDIR/test2
SLAVEDATA
) >> wal-slave.ini

$PSQL -p $PORT -U $USER postgres -c "CREATE DATABASE pgbench"

/usr/lib/postgresql/9.2/bin/pgbench -i -s 1 pgbench -h /tmp -p ${PORT}

echo "## Setting up walmgr3"
walmgr3 $HOMEDIR/wal-master.ini setup

#mkdir -p $HOMEDIR/test2

echo "## Backing up"
walmgr3 $HOMEDIR/wal-master.ini backup
echo "## Done with backup"

echo "## Creating replica"
walmgr3 $HOMEDIR/wal-slave.ini restore data.master
echo "## Done with creating replica"

( 
cat <<-NEWPORT
port=$PORT2
NEWPORT
) >> ${DEMO2}/postgresql.conf

echo "## Starting $DEMO2"
$PGCTL -D ${DEMO2} start > ${DEMO2}.log 2>&1

echo "# DONE"

