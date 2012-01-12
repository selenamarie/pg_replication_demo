#!/bin/sh

source variables.sh

pg_ctl -D $DATA_DIR stop -m immediate
pg_ctl -D ${DATA_DIR}_repl stop -m immediate

rm -rf $DATA_DIR
rm -rf ${DATA_DIR}_repl
rm -rf $WAL
