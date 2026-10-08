#!/bin/bash

MISP_LOG_SESSION="misp-log"
MISP_SESSION="misp"
LOG_PATH="/data/docker/customer/log/mispsyslog.log"
DOCKER_COMPOSE_DIR="/data/docker/misp-docker/"
DOCKER_COMPOSE_FILE="docker-compose.yml"
LOG_LINES=100
# "label:compose service" - valkey runs as the "redis" service
REQUIRED_SERVICES=("misp-core:misp-core" "valkey:redis" "db:db" "misp-modules:misp-modules")

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

logs_containers() {
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

status_containers() {
    local failed=0

    log_message "Checking required containers..."
    for entry in "${REQUIRED_SERVICES[@]}"; do
        label="${entry%%:*}"
        service="${entry#*:}"
        container_id=$(docker compose -f "$DOCKER_COMPOSE_DIR$DOCKER_COMPOSE_FILE" ps -q "$service" 2>/dev/null)
        if [ -z "$container_id" ]; then
            log_message "[FAIL] $label: no container found."
            failed=1
            continue
        fi

        state=$(docker inspect -f '{{.State.Status}}' "$container_id")
        health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$container_id")
        if [ "$state" = "running" ] && [ "$health" != "unhealthy" ]; then
            log_message "[ OK ] $label: $state${health:+ ($health)}"
        else
            log_message "[FAIL] $label: $state${health:+ ($health)}"
            failed=1
        fi
    done

    if [ $failed -ne 0 ]; then
        log_message "One or more containers are not running."
        exit 1
    fi
    log_message "All containers are running."
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
    logs)
        logs_containers
        ;;
    shell)
        shell_container
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs|shell}"
        exit 1
        ;;
esac

exit 0
