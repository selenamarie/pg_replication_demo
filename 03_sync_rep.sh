#!/bin/bash

source variables.sh
PSQL='psql postgres -c'
PGCTL="pg_ctl -D ${DEMO}"


initdb -D ${DATA_DIR} -E UTF8 

# create wal storage directory 
mkdir $WAL

# Update pg_hba.conf
echo "local   replication     selena                                trust" >> ${DEMO}/pg_hba.conf
echo "local   selena          selena                                trust" >> ${DEMO}/pg_hba.conf
echo "host    replication     selena        127.0.0.1/32            trust" >> ${DEMO}/pg_hba.conf
echo "host    replication     selena        ::1/128                 trust" >> ${DEMO}/pg_hba.conf

# Update postgresql.conf
echo "wal_level = 'hot_standby'"                                                        >> ${DEMO}/postgresql.conf
echo "max_wal_senders = 10"                                                             >> ${DEMO}/postgresql.conf
echo "archive_mode  = on"                                                               >> ${DEMO}/postgresql.conf
echo "archive_command  = 'test ! -f ${WAL}/%f && cp -i %p ${WAL}/%f'"               >> ${DEMO}/postgresql.conf
echo "synchronous_standby_names = '${DEMO}'"                                            >> ${DEMO}/postgresql.conf

pg_ctl -D $DATA_DIR start -l $DATA_DIR.log

sleep 2 

echo "Making base backup"

# Make a base backup
pg_basebackup -D ${DEMO_REPL} -U selena -v

sleep 1

# Augment postgresql.conf for hotstandby!

echo "hot_standby = on"                                                                     >> ${DEMO_REPL}/postgresql.conf

# Create recovery.conf
echo "restore_command = 'cp /tmp/wal/%f %p'"                                                 >> ${DEMO_REPL}/recovery.conf 
echo "standby_mode = on"                                                                     >> ${DEMO_REPL}/recovery.conf
echo "primary_conninfo = 'host=localhost port=5432 user=selena application_name=$DEMO'"      >> ${DEMO_REPL}/recovery.conf
echo "trigger_file = '/tmp/trig_f_newcluster'"                                               >> ${DEMO_REPL}/recovery.conf

# Change port listener for replication
echo "port = 5433"                                            >> ${DEMO_REPL}/postgresql.conf

pg_ctl -D ${DEMO_REPL} start -l ${DEMO_REPL}.log

$PSQL "create database selena"


