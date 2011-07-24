#!/bin/bash
export PATH=/opt/pg91beta2/bin:$PATH

WAL=/tmp/oscon_demo_wal
DEMO=oscon_demo
DEMO_REPL=oscon_demo_repl

PSQL='psql -AX -qt postgres -c'
PGCTL="pg_ctl -D ${DEMO}"


# Create replication user
$PSQL "CREATE ROLE replication REPLICATION LOGIN"
$PSQL "GRANT replication TO selena"

# Update pg_hba.conf
echo "local   replication     selena                                trust" >> ${DEMO}/pg_hba.conf
echo "host    replication     selena        127.0.0.1/32            trust" >> ${DEMO}/pg_hba.conf
echo "host    replication     selena        ::1/128                 trust" >> ${DEMO}/pg_hba.conf


# create wal storage directory if it doesn't already exist
if [[ ! -x /tmp/wal ]]; then
    mkdir -p /tmp/wal
fi

# Update postgresql.conf
echo "wal_level = 'hot_standby'"                                                        >> ${DEMO}/postgresql.conf
echo "max_wal_senders = 10"                                                             >> ${DEMO}/postgresql.conf
echo "archive_mode  = on"                                                               >> ${DEMO}/postgresql.conf
echo "archive_command  = 'test ! -f /tmp/wal/%f && cp -i %p /tmp/wal/%f'"               >> ${DEMO}/postgresql.conf
echo "synchronous_standby_names = '${DEMO}'"                                            >> ${DEMO}/postgresql.conf

$PGCTL restart

sleep 2

# Make a base backup
pg_basebackup -D ${DEMO_REPL} -U selena -v

sleep 1

# Create recovery.conf
echo "restore_command = 'cp /tmp/wal/%f %p'"                                                 >> ${DEMO_REPL}/recovery.conf 
echo "standby_mode = on"                                                                     >> ${DEMO_REPL}/recovery.conf
echo "primary_conninfo = 'host=localhost port=5432 user=selena application_name=oscon_demo'" >> ${DEMO_REPL}/recovery.conf
echo "trigger_file = '/tmp/trig_f_newcluster'"                                               >> ${DEMO_REPL}/recovery.conf

# Change port listener for replication
echo "port = 5433"                                            >> ${DEMO_REPL}/postgresql.conf

pg_ctl -D ${DEMO_REPL} start -l oscon_demo_repl.log
