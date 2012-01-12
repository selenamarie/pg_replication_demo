#!/bin/sh

source variables.sh
pg_ctl -D $DATA_DIR start -l $DATA_DIR.log
