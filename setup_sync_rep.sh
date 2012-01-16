#!/bin/bash

source variables.sh

PSQL='/demo/pg92/bin/psql postgres -c'
PGCTL="/demo/pg92/bin/pg_ctl -D ${DEMO}"

/demo/pg92/bin/initdb -D ${DATA_DIR} -E UTF8 

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
#echo "synchronous_standby_names = '${DEMO}'"                                           >> ${DEMO}/postgresql.conf
echo "wal_keep_segments = 100"                                                          >> ${DEMO}/postgresql.conf


/demo/pg92/bin/pg_ctl -D $DATA_DIR start -l $DATA_DIR.log

sleep 2 

echo "Making base backup"

# Make a base backup
/demo/pg92/bin/pg_basebackup -D ${DEMO_REPL} -U selena -v

sleep 2

# Augment postgresql.conf for hotstandby!

echo "hot_standby = on"                                                                     >> ${DEMO_REPL}/postgresql.conf

# Create recovery.conf
echo "restore_command = 'cp -i ${WAL}/%f %p'"                                               >> ${DEMO_REPL}/recovery.conf 
echo "standby_mode = on"                                                                    >> ${DEMO_REPL}/recovery.conf
#echo "primary_conninfo = 'host=localhost port=5432 user=selena application_name=${DEMO}'"  >> ${DEMO_REPL}/recovery.conf
echo "primary_conninfo = 'host=localhost port=5432 user=selena'"                            >> ${DEMO_REPL}/recovery.conf
echo "trigger_file = '/tmp/trig_recovery'"                                                  >> ${DEMO_REPL}/recovery.conf
echo "wal_keep_segments = 100"                                                              >> ${DEMO_REPL}/postgresql.conf

# Change port listener for replication
echo "port = 5433"                                                                          >> ${DEMO_REPL}/postgresql.conf

echo "local   replication     selena                                trust" >> ${DEMO_REPL}/pg_hba.conf
echo "local   selena          selena                                trust" >> ${DEMO_REPL}/pg_hba.conf
echo "host    replication     selena        127.0.0.1/32            trust" >> ${DEMO_REPL}/pg_hba.conf
echo "host    replication     selena        ::1/128                 trust" >> ${DEMO_REPL}/pg_hba.conf

echo "Starting repl"
/demo/pg92/bin/pg_ctl -D ${DEMO_REPL} start -l ${DEMO_REPL}.log

echo "Creating database selena"
$PSQL "create database selena"

## Set up cascaded slaves

echo "Creating other base backups"
/demo/pg92/bin/pg_basebackup -D ${DEMO_REPL2} -U selena -v
/demo/pg92/bin/pg_basebackup -D ${DEMO_REPL3} -U selena -v

# Create recovery.conf
for i in ${DEMO_REPL2} ${DEMO_REPL3} ; do 
    echo "restore_command = 'cp -i ${WAL}/%f %p'"                                                       >> ${DEMO_REPL}/recovery.conf 
    echo "standby_mode = on"                                                                     >> $i/recovery.conf
    # echo "primary_conninfo = 'host=localhost port=5433 user=selena application_name=${DEMO}'"  >> $i/recovery.conf
    echo "primary_conninfo = 'host=localhost port=5433 user=selena'"                             >> $i/recovery.conf
    echo "trigger_file = '/tmp/trig_recovery'"                                                   >> $i/recovery.conf
    echo "archive_command  = '/bin/true'"                                                        >> $i/postgresql.conf
    echo "hot_standby = on"                                                                      >> $i/postgresql.conf
done

perl -pi -e 's/trig_recovery/trig_recovery2/' ${DEMO_REPL2}/recovery.conf
perl -pi -e 's/trig_recovery/trig_recovery3/' ${DEMO_REPL3}/recovery.conf

echo "port = 5434"                                            >> ${DEMO_REPL2}/postgresql.conf
echo "port = 5435"                                            >> ${DEMO_REPL3}/postgresql.conf

echo "Done!"
# Start 'em up
for a in ${DEMO_REPL2} ${DEMO_REPL3}; do 
    echo "Starting $a"
    /demo/pg92/bin/pg_ctl -D $a/ start -l $a.log
done

