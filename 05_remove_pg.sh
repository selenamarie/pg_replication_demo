export PATH=/opt/pg91beta2/bin:$PATH
pg_ctl -D oscon_demo stop -m immediate
pg_ctl -D oscon_demo_repl stop -m immediate

rm -rf oscon_demo
rm -rf oscon_demo_repl
rm -rf /tmp/wal
