#!/bin/bash

. variables.sh

$PGCTL -D ${DEMO} stop -m fast
rm -rf ${DEMO}

$PGCTL -D ${DEMO2} stop -m fast
rm -rf ${DEMO2}
