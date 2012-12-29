
BACKUPDIR=/tmp/barman
BARMANHOME=$(pwd)
LOGDIR=/var/log/barman

PORT=8000
PORT2=8002
USER="selena"
DEMO="test"
DEMO2="test2"
HOSTNAME=$(hostname) #default name for backup files

PGCTL="/usr/lib/postgresql/9.2/bin/pg_ctl"
PSQL="psql -h /tmp"
