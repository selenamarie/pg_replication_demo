
HOMEDIR=$(pwd)
ARCDIR=$HOMEDIR/wal_archive
RMANHOMEDIR="$HOMEDIR/pg_rman"
LOGDIR=/var/log/pg_rman

PORT=8000
PORT2=8002
USER="selena"
DEMO="test"
DEMO2="test2"
HOSTNAME=$(hostname) #default name for backup files

PGCTL="/usr/lib/postgresql/9.2/bin/pg_ctl"
PSQL="psql -h /tmp"
