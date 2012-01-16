#!/bin/bash

source variables.sh
PSQL='/demo/pg92/bin/psql postgres -c'
PGCTL="/demo/pg92/bin/pg_ctl"
INITDB=/demo/pg92/bin/initdb
PGBASEBACKUP=/demo/pg92/bin/pg_basebackup

#### Create Master ####
$INITDB -D ${DATA_DIR} -E UTF8 

#### Create wal storage directory ####

mkdir $WAL

#### Update pg_hba.conf ####
(
cat <<-DEMO
	local   replication     selena                                trust
	local   selena          selena                                trust
	host    replication     selena        127.0.0.1/32            trust
	host    replication     selena        ::1/128                 trust
DEMO
)  >> ${DEMO}/pg_hba.conf

echo "done hba"

#### Update postgresql.conf for master db ####
(
cat <<-DEMOPG
	wal_level = 'hot_standby'
	max_wal_senders = 10
	archive_mode  = on
	archive_command  = 'test ! -f ${WAL}/%f && cp -i %p ${WAL}/%f'
	wal_keep_segments = 100
DEMOPG
) >> ${DEMO}/postgresql.conf

echo "done postgresql.conf"
#echo "synchronous_standby_names = '${DEMO}'"                              >> ${DEMO}/postgresql.conf

#### Start postgres master ####
$PGCTL -D $DATA_DIR start -l $DATA_DIR.log

sleep 2 

echo "#### Making base backup ####"

#### Make a base backup ####
$PGBASEBACKUP -D ${DEMO_REPL} -U selena -v

sleep 2

#### Augment postgresql.conf for hotstandby! ####

echo "hot_standby = on"                                                                     >> ${DEMO_REPL}/postgresql.conf

#### Create recovery.conf ####
(
cat <<-DEMOREPL
	restore_command = 'cp -i ${WAL}/%f %p'
	standby_mode = on
	primary_conninfo = 'host=localhost port=5432 user=selena'
	trigger_file = '/tmp/trig_recovery'
DEMOREPL
) >> ${DEMO_REPL}/recovery.conf

#### Change port listener for replication ####
( 
cat <<-DEMOREPLPG
	wal_keep_segments = 100
	port = 5433
DEMOREPLPG
) >> ${DEMO_REPL}/postgresql.conf

#echo "primary_conninfo = 'host=localhost port=5432 user=selena application_name=${DEMO}'"  >> ${DEMO_REPL}/recovery.conf

(
cat <<-DEMOREPLHBA
	local   replication     selena                                trust
	local   selena          selena                                trust
	host    replication     selena        127.0.0.1/32            trust
	host    replication     selena        ::1/128                 trust
DEMOREPLHBA
) >> ${DEMO_REPL}/pg_hba.conf

echo "#### Starting repl ####"
#### Starting replication ####
$PGCTL -D ${DEMO_REPL} start -l ${DEMO_REPL}.log

echo "#### Creating database selena ####"
$PSQL "create database selena"

#### Set up cascaded slaves ####

echo "#### Creating other base backups ####"
$PGBASEBACKUP -D ${DEMO_REPL2} -U selena -v
$PGBASEBACKUP -D ${DEMO_REPL3} -U selena -v

#### Create .conf ####
for i in ${DEMO_REPL2} ${DEMO_REPL3} ; do 
	(
	cat <<-DEMORECOVERY
		restore_command = 'cp -i ${WAL}/%f %p'
		standby_mode = on
		primary_conninfo = 'host=localhost port=5433 user=selena'
		trigger_file = '/tmp/trig_recovery'
	DEMORECOVERY
	) >> $i/recovery.conf
	( 
	cat <<-DEMORECOVERYPG
		archive_command  = '/bin/true'
		hot_standby = on
	DEMORECOVERYPG
	) >> $i/postgresql.conf
done
# primary_conninfo = 'host=localhost port=5433 user=selena application_name=${DEMO}'

perl -pi -e 's/trig_recovery/trig_recovery2/' ${DEMO_REPL2}/recovery.conf
perl -pi -e 's/trig_recovery/trig_recovery3/' ${DEMO_REPL3}/recovery.conf

echo "port = 5434"  >> ${DEMO_REPL2}/postgresql.conf
echo "port = 5435"  >> ${DEMO_REPL3}/postgresql.conf

#### Start 'em up ####
echo "#### Starting up the replicated systems ####"

for a in ${DEMO_REPL2} ${DEMO_REPL3}; do 
    echo "Starting $a"
    $PGCTL -D $a/ start -l $a.log
done

echo "Done!"

sleep 1

ps -ef | grep postgres

echo 

sleep 5

ps -ef | grep postgres
