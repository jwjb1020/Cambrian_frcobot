#!/bin/bash

# ===================================
# Fairino Network Routing Setup Script
# ===================================
# Usage: sudo bash fairino_network_setup.sh
# ===================================

# Configuration
DOCKER_BRIDGE="br-1771327d712f"
VIRTUAL_ROBOT_IP="192.168.58.2"
CAMERA_PC_IP="192.168.58.200"
LAN_INTERFACE="enp12s0"
CONTAINER_NAME="fairino-container"
GATEWAY_IP="192.168.58.1"

if [ "$EUID" -ne 0 ]; then
    echo "Error: this script must be run with sudo."
    echo "  sudo bash $0"
    exit 1
fi

echo "======================================"
echo " Fairino Network Routing Setup"
echo "======================================"

# 1. Check Docker status
echo ""
echo "[1/4] Checking Docker status..."
if ! systemctl is-active --quiet docker; then
    echo "  Docker is not running. Starting..."
    systemctl start docker
    sleep 2
fi
echo "  Docker is running ✅"

# 2. Check container status
echo ""
echo "[2/4] Checking fairino-container status..."
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "  Container is not running. Starting..."
    docker start "$CONTAINER_NAME"
    sleep 3
fi
echo "  Container is running ✅"

# 3. Configure routing
echo ""
echo "[3/4] Configuring routes..."

# Remove Docker bridge catch-all route (if it exists)
if ip route | grep -q "192.168.58.0/24 dev $DOCKER_BRIDGE"; then
    if ip route del 192.168.58.0/24 dev "$DOCKER_BRIDGE" 2>/dev/null; then
        echo "  Docker bridge catch-all route removed ✅"
    else
        echo "  Failed to remove Docker bridge route ❌ (check sudo privileges)"
        exit 1
    fi
else
    echo "  No Docker bridge catch-all route found (skipped)"
fi

# Add virtual robot route (if not already present)
if ! ip route | grep -q "$VIRTUAL_ROBOT_IP"; then
    if ip route add "$VIRTUAL_ROBOT_IP/32" dev "$DOCKER_BRIDGE" 2>/dev/null; then
        echo "  Virtual robot route added ✅"
    else
        echo "  Failed to add virtual robot route ❌ (check sudo privileges)"
        exit 1
    fi
else
    echo "  Virtual robot route already exists (skipped)"
fi

# Add camera PC route (if not already present)
if ! ip route | grep -q "$CAMERA_PC_IP"; then
    if ip route add "$CAMERA_PC_IP/32" dev "$LAN_INTERFACE" 2>/dev/null; then
        echo "  Camera PC route added ✅"
    else
        echo "  Failed to add camera PC route ❌ (check sudo privileges)"
        exit 1
    fi
else
    echo "  Camera PC route already exists (skipped)"
fi

# 4. Configure routing inside Docker container
echo ""
echo "[4/4] Configuring routes inside container..."
docker exec "$CONTAINER_NAME" ip route add "$CAMERA_PC_IP" via "$GATEWAY_IP" 2>/dev/null
echo "  Container internal camera PC route added ✅"

# 5. Connectivity tests
echo ""
echo "======================================"
echo " Connectivity Tests"
echo "======================================"

echo ""
echo "Pinging virtual robot ($VIRTUAL_ROBOT_IP)..."
if ping -c 2 -W 2 "$VIRTUAL_ROBOT_IP" > /dev/null 2>&1; then
    echo "  Virtual robot reachable ✅"
else
    echo "  Virtual robot unreachable ❌"
fi

echo ""
echo "Pinging camera PC ($CAMERA_PC_IP)..."
if ping -c 2 -W 2 "$CAMERA_PC_IP" > /dev/null 2>&1; then
    echo "  Camera PC reachable ✅"
else
    echo "  Camera PC unreachable ❌"
fi

echo ""
echo "======================================"
echo " Setup complete!"
echo "======================================"
echo ""
echo " Robot web UI: http://$VIRTUAL_ROBOT_IP"
echo " Login: admin / Password: 123"
echo ""
