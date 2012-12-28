#!/bin/bash

. variables.sh

$PGCTL -D ${DEMO} stop -m fast
rm -rf ${DEMO}
rm ${DEMO}.log

$PGCTL -D ${DEMO2} stop -m fast
rm -rf ${DEMO2}
rm ${DEMO2}.log
