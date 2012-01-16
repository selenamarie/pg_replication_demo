#!/bin/sh

source variables.sh

for i in ${DATA_DIR} ${DEMO_REPL} ${DEMO_REPL2} ${DEMO_REPL3} ; do
    pg_ctl -D $i stop -m immediate
    rm -rf $i
    rm -rf $i.log
done

rm -rf $WAL
