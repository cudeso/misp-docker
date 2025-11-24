#!/bin/bash

term_procs() {
    echo "Entrypoint CRON caught SIGTERM signal!"
    echo "Killing process $p1_pid"
    kill -TERM "$p1_pid" 2>/dev/null
    echo "Killing process $p2_pid"
    kill -TERM "$p2_pid" 2>/dev/null
}

trap term_procs SIGTERM


# Build a fifo buffer for the cron logs, 777 so anyone can write to it
if [[ ! -p /tmp/cronlog ]]; then
    mkfifo -m 777 /tmp/cronlog
fi

# Build another fifo for the cron pipe
if [[ ! -p /tmp/cronpipe ]]; then
    mkfifo /tmp/cronpipe
fi

# Execute the cron pipe
cron -l -f > /tmp/cronpipe & p1_pid=$!
tail -f /tmp/cronlog < /tmp/cronpipe & p2_pid=$!

# Wait for both processes of the cron pipe
wait "$p2_pid"
wait "$p1_pid"
