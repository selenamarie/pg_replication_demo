
TESTPATH=$(pwd)
BACKUPDIR="hot_standby"
OMNIPATH="~/repos/omnipitr/bin"
STATEPATH="/tmp/omnipitr/state"
TMPPATH="/tmp/omnipitr"
LOGPATH="/var/log/omnipitr"
PATH=$PATH:~/repos/omnipitr/bin
PERL5LIB="$PERL5LIB:~/repos/omnipitr/lib"
PORT=8000
PORT2=8002
USER="selena"
DEMO="test"
DEMO2="test2"
HOSTNAME=$(hostname) #default name for backup files

PGCTL="/usr/lib/postgresql/9.2/bin/pg_ctl"
PSQL="psql -h /tmp"
