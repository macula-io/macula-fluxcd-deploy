#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="/tmp/macula-socat"

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Macula Port Forwarding Setup                          ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Create PID directory
mkdir -p "$PID_DIR"

# Function to start a forwarding rule
start_forward() {
    local name=$1
    local bind_ip=$2
    local bind_port=$3
    local target_ip=$4
    local target_port=$5
    local pid_file="$PID_DIR/${name}.pid"

    # Check if already running
    if [ -f "$pid_file" ] && kill -0 $(cat "$pid_file") 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC}  $name already running (PID $(cat "$pid_file"))"
        return
    fi

    # Start socat in background
    socat TCP-LISTEN:${bind_port},bind=${bind_ip},reuseaddr,fork TCP:${target_ip}:${target_port} &
    local socat_pid=$!

    # Save PID
    echo $socat_pid > "$pid_file"

    echo -e "  ${GREEN}✓${NC} $name: ${bind_ip}:${bind_port} → ${target_ip}:${target_port} (PID $socat_pid)"
}

# Stop all forwarding
stop_all() {
    echo -e "${CYAN}▸${NC} Stopping all port forwarding..."
    for pid_file in "$PID_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            pid=$(cat "$pid_file")
            if kill -0 $pid 2>/dev/null; then
                kill $pid
                echo -e "  ${GREEN}✓${NC} Stopped $(basename "$pid_file" .pid) (PID $pid)"
            fi
            rm "$pid_file"
        fi
    done
    echo ""
}

# Check command
case "${1:-start}" in
    start)
        echo -e "${CYAN}▸${NC} Starting port forwarding..."
        echo ""

        # KinD Cluster Applications (127.0.0.2 → 127.0.0.1:8080/8443)
        echo -e "${CYAN}Applications (KinD):${NC}"
        start_forward "kind-http" "127.0.0.2" "80" "127.0.0.1" "8080"
        start_forward "kind-https" "127.0.0.2" "443" "127.0.0.1" "8443"
        echo ""

        # Observability Stack (127.0.0.3-6 → 172.23.0.20-23)
        echo -e "${CYAN}Observability:${NC}"
        start_forward "prometheus" "127.0.0.3" "9090" "172.23.0.20" "9090"
        start_forward "grafana" "127.0.0.4" "3000" "172.23.0.21" "3000"
        start_forward "loki" "127.0.0.5" "3100" "172.23.0.22" "3100"
        start_forward "tempo" "127.0.0.6" "3200" "172.23.0.23" "3200"
        echo ""

        # Development Tools (127.0.0.7 → 172.23.0.24)
        echo -e "${CYAN}Development Tools:${NC}"
        start_forward "excalidraw" "127.0.0.7" "80" "172.23.0.24" "80"
        echo ""

        # Data Services (127.0.0.8-9 → 172.23.0.30-31)
        echo -e "${CYAN}Data Services:${NC}"
        start_forward "timescaledb" "127.0.0.8" "5432" "172.23.0.31" "5432"
        start_forward "minio-api" "127.0.0.9" "9000" "172.23.0.30" "9000"
        start_forward "minio-console" "127.0.0.9" "9001" "172.23.0.30" "9001"
        echo ""

        echo "╔════════════════════════════════════════════════════════╗"
        echo "║  Port Forwarding Active                                ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        echo "PIDs stored in: $PID_DIR"
        echo ""
        echo "Stop: $0 stop"
        echo "Status: $0 status"
        ;;

    stop)
        stop_all
        echo -e "${GREEN}✓${NC} All port forwarding stopped"
        ;;

    status)
        echo -e "${CYAN}Port Forwarding Status:${NC}"
        echo ""
        if [ ! -d "$PID_DIR" ] || [ -z "$(ls -A "$PID_DIR")" ]; then
            echo "  No forwarding rules active"
        else
            for pid_file in "$PID_DIR"/*.pid; do
                if [ -f "$pid_file" ]; then
                    name=$(basename "$pid_file" .pid)
                    pid=$(cat "$pid_file")
                    if kill -0 $pid 2>/dev/null; then
                        echo -e "  ${GREEN}✓${NC} $name (PID $pid)"
                    else
                        echo -e "  ${RED}✗${NC} $name (stale PID $pid)"
                    fi
                fi
            done
        fi
        echo ""
        ;;

    restart)
        stop_all
        sleep 1
        $0 start
        ;;

    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
