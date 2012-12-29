#!/bin/bash

. variables.sh

rm -rf $RMANHOMEDIR
sudo rm -rf $LOGDIR

$PGCTL -D ${DEMO} stop -m fast
rm -rf ${DEMO}
rm ${DEMO}.log
rm -rf $ARCDIR

$PGCTL -D ${DEMO2} stop -m fast
rm -rf ${DEMO2}
rm ${DEMO2}.log

rm -rf hot_standby/*

