#!/bin/bash

# === LOAD CONFIG FROM .env IF EXISTS ===
if [ -f "./.env" ]; then
    source ./.env
fi

# === GET INPUTS FROM ENV OR USER ===
read -p "Remote IP [${REMOTE_IP:-}]: " input_ip
REMOTE_IP="${input_ip:-$REMOTE_IP}"

read -p "Expected hostname [${EXPECTED_HOSTNAME:-}]: " input_host
EXPECTED_HOSTNAME="${input_host:-$EXPECTED_HOSTNAME}"

read -p "SSH username [${SSH_USER:-}]: " input_user
SSH_USER="${input_user:-$SSH_USER}"

read -p "noVNC port [${NOVNC_PORT:-6080}]: " input_port
NOVNC_PORT="${input_port:-${NOVNC_PORT:-6080}}"

NOVNC_URL="http://$REMOTE_IP:$NOVNC_PORT/vnc.html"

# === STEP 1: Ping ===
echo "[*] Pinging $REMOTE_IP..."
if ! ping -c 2 "$REMOTE_IP" >/dev/null; then
    echo "[!] Cannot reach $REMOTE_IP"
    exit 1
fi
echo "[+] Host is reachable."

# === STEP 2: Verify hostname ===
echo "[*] Verifying remote hostname..."
ACTUAL_HOSTNAME=$(ssh "$SSH_USER@$REMOTE_IP" 'hostname' 2>/dev/null)
if [[ "$ACTUAL_HOSTNAME" != "$EXPECTED_HOSTNAME" ]]; then
    echo "[!] Hostname mismatch. Got: $ACTUAL_HOSTNAME, Expected: $EXPECTED_HOSTNAME"
    exit 1
fi
echo "[+] Hostname match confirmed."

# === STEP 3: Launch krfb + noVNC ===
echo "[*] Launching krfb + websockify on remote..."
ssh "$SSH_USER@$REMOTE_IP" <<'EOF'
    pkill krfb; pkill websockify
    nohup krfb --no-notification --address=127.0.0.1 --port=5900 --password=ask > /dev/null 2>&1 &
    nohup websockify --web=/usr/share/novnc/ 6080 localhost:5900 > /tmp/novnc.log 2>&1 &
EOF
echo "[+] Remote VNC and noVNC started."

# === STEP 4: Open Browser ===
echo "[*] Opening browser to $NOVNC_URL"
xdg-open "$NOVNC_URL" >/dev/null 2>&1 &

echo "[✓] Complete."
