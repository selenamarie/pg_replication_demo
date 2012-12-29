#!/bin/bash

. variables.sh

$PGCTL -D ${DEMO} stop -m fast
rm -rf ${DEMO}
rm ${DEMO}.log
rm -rf /tmp/wal_archive

$PGCTL -D ${DEMO2} stop -m fast
rm -rf ${DEMO2}
rm ${DEMO2}.log
