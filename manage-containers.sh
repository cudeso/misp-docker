#!/bin/bash

MISP_LOG_SESSION="misp-log"
MISP_SESSION="misp"
LOG_PATH="/data/docker/customer/log/mispsyslog.log"
DOCKER_COMPOSE_DIR="/data/docker/misp-docker/"
DOCKER_COMPOSE_FILE="docker-compose.yml"
LOG_LINES=100

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

start_containers() {
    log_message "Starting tmux sessions..."

    tmux new-session -d -s "$MISP_LOG_SESSION" "tail -f $LOG_PATH & bash"
    if [ $? -ne 0 ]; then
        log_message "Failed to start tmux session: $MISP_LOG_SESSION."
        exit 1
    fi

    tmux new-session -d -s "$MISP_SESSION" "cd $DOCKER_COMPOSE_DIR && docker compose -f $DOCKER_COMPOSE_FILE up -d & bash"
    if [ $? -ne 0 ]; then
        log_message "Failed to start tmux session: $MISP_SESSION."
        exit 1
    fi

    log_message "Started tmux sessions successfully."
    tmux list-sessions -F "#{session_id}: #{session_name}"
}

stop_containers() {
    log_message "Stopping Docker containers..."
    docker compose -f "$DOCKER_COMPOSE_DIR$DOCKER_COMPOSE_FILE" down
    if [ $? -ne 0 ]; then
        log_message "Failed to stop Docker containers."
        exit 1
    fi

    sleep 5

    log_message "Stopping tmux sessions..."
    tmux kill-session -t "$MISP_SESSION" 2>/dev/null
    if [ $? -ne 0 ]; then
        log_message "Failed to kill tmux session: $MISP_SESSION (it might not exist)."
    fi

    tmux kill-session -t "$MISP_LOG_SESSION" 2>/dev/null
    if [ $? -ne 0 ]; then
        log_message "Failed to kill tmux session: $MISP_LOG_SESSION (it might not exist)."
    fi

    log_message "Stopped all services."

    docker compose -f "$DOCKER_COMPOSE_DIR$DOCKER_COMPOSE_FILE" ps
}

status_containers() {
    for session in "$MISP_SESSION" "$MISP_LOG_SESSION"; do
        log_message "Grabbing output '$session:0.0'"
        echo " "
        if tmux has-session -t "$session" 2>/dev/null; then
            tmux capture-pane -p -t "$session:0.0"
        else
            log_message "tmux session $session is not running."
        fi
        echo " "
    done

    log_message "Docker containers"
    docker compose -f "$DOCKER_COMPOSE_DIR$DOCKER_COMPOSE_FILE" ps

    log_message "Docker logs (last $LOG_LINES lines per container)"
    docker compose -f "$DOCKER_COMPOSE_DIR$DOCKER_COMPOSE_FILE" logs --tail "$LOG_LINES"
}

shell_container() {
    log_message "Starting /bin/bash in misp-core container..."
    docker compose -f "$DOCKER_COMPOSE_DIR$DOCKER_COMPOSE_FILE" exec misp-core /bin/bash
}

case "$1" in
    start)
        start_containers
        ;;
    stop)
        stop_containers
        ;;
    status)
        status_containers
        ;;
    shell)
        shell_container
        ;;
    *)
        echo "Usage: $0 {start|stop|status|shell}"
        exit 1
        ;;
esac

exit 0
