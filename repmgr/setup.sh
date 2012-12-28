#!/bin/bash

. variables.sh

REPMGRCONF="/etc/repmgr/"
REPLOG="/var/log/repmgr/"

(
cat <<-RMC
cluster=${DEMO}
node=1
node_name=earth
conninfo='host=localhost user=repmgr dbname=pgbench port=${PORT}'
# How many seconds we wait for master response before declaring master failure
master_response_timeout=60

# How many time we try to reconnect to master before starting failover procedure
reconnect_attempts=6
reconnect_interval=10

# Autofailover options
failover=automatic
priority=-1
promote_command='repmgr standby promote -f ${REPMGRCONF}/repmgr.conf'
follow_command='repmgr standby follow -f ${REPMGRCONF}/repmgr.conf -W'
RMC
) > ${REPMGRCONF}/repmgr.conf

(
cat <<-RMC2
cluster=${DEMO}
node=2
node_name=mars
conninfo='host=localhost user=repmgr dbname=pgbench port=${PORT2}'

# How many seconds we wait for master response before declaring master failure
master_response_timeout=60

# How many time we try to reconnect to master before starting failover procedure
reconnect_attempts=6
reconnect_interval=10

# Autofailover options
failover=automatic
priority=-1
promote_command='repmgr standby promote -f ${REPMGRCONF}/repmgr2.conf'
follow_command='repmgr standby follow -f ${REPMGRCONF}/repmgr2.conf -W'
RMC2
) > ${REPMGRCONF}/repmgr2.conf

/usr/lib/postgresql/9.2/bin/initdb ${DEMO}

cp postgresql.conf ${DEMO}/postgresql.conf

#### Update pg_hba.conf ####
(
cat <<-DEMO
	local   replication     $USER                                trust
	host    replication     $USER        127.0.0.1/32            trust
	host    replication     $USER        ::1/128                 trust
	host    replication     repmgr        127.0.0.1/32            trust
	host    replication     repmgr        ::1/128                 trust
DEMO
)  >> ${DEMO}/pg_hba.conf

$PGCTL -D ${DEMO} start > ${DEMO}.log 2>&1

sleep 3

$PSQL -p $PORT -U $USER postgres -c "CREATE ROLE repmgr LOGIN SUPERUSER"
$PSQL -p $PORT -U $USER postgres -c "CREATE DATABASE pgbench"

/usr/lib/postgresql/9.2/bin/pgbench -i -s 1 pgbench -h /tmp -p ${PORT}

echo "CLONING"
# Clone our test database
PGDATA=/home/selena/repos/pg_replication_demo/repmgr/test2 PGPORT=${PORT2} repmgr -D ${DEMO2} -d pgbench -p $PORT -U repmgr -R $USER --verbose standby clone localhost

echo "DONE CLONING"

( 
cat <<-NEWPORT
port=$PORT2
NEWPORT
) >> ${DEMO2}/postgresql.conf

$PGCTL -D ${DEMO2} start > ${DEMO2}.log 2>&1

repmgr -f ${REPMGRCONF}/repmgr.conf --verbose master register 

PGENGINE=/usr/lib/postgresql/9.2/bin PATH="$PATH:$PGENGINE" repmgrd -f ${REPMGRCONF}/repmgr.conf --verbose > ${REPLOG}/repmgr.log 2>&1 & 

sleep 4

PGENGINE=/usr/lib/postgresql/9.2/bin PATH="$PATH:$PGENGINE" repmgrd -f ${REPMGRCONF}/repmgr2.conf --verbose > ${REPLOG}/repmgr2.log 2>&1 & 

#repmgr -f ${REPMGRCONF}/repmgr2.conf --verbose standby register
