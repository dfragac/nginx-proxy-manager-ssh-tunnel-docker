#!/command/with-contenv bash
# shellcheck shell=bash

# Required environment variables:
#   SSH_SERVER - Public SSH server (e.g.: example.com)
#   SSH_PORT - SSH server port (default: 22)
#   SSH_USER - SSH user
#   SSH_PASSWORD - SSH password (optional)
#   SSH_CHECK_INTERVAL - Tunnel verification interval (default: 60 seconds)
#   SSH_MAX_FAILURES - Maximum number of consecutive failures before marking tunnel as inactive (default: 5)
#   LOCAL_HTTP_PORT - Local HTTP port (default: 80)
#   LOCAL_HTTPS_PORT - Local HTTPS port (default: 443)
#   REMOTE_HTTP_PORT - Remote HTTP port (default: 80)
#   REMOTE_HTTPS_PORT - Remote HTTPS port (default: 443)

# Default values
## SSH
SSH_PORT=${SSH_PORT:-22}
SSH_USER=${SSH_USER:-root}
LOCAL_HTTP_PORT=${LOCAL_HTTP_PORT:-80}
LOCAL_HTTPS_PORT=${LOCAL_HTTPS_PORT:-443}
REMOTE_HTTP_PORT=${REMOTE_HTTP_PORT:-80}
REMOTE_HTTPS_PORT=${REMOTE_HTTPS_PORT:-443}

## Variables for monitoring
SSH_CHECK_INTERVAL=${SSH_CHECK_INTERVAL:-60}
SSH_MAX_FAILURES=${SSH_MAX_FAILURES:-5}
SSH_CONSECUTIVE_FAILURES=0
SSH_TUNNEL_STATUS="DOWN"

#
# Auxiliary functions.
#

# More robust variable validation
validate_environment() {
    local errors=0

    if [ -z "$SSH_SERVER" ]; then
        log_event "ERROR" "SSH_SERVER is required"
        errors=$((errors + 1))
    fi

    # Validate port format
    for port in $SSH_PORT $LOCAL_HTTP_PORT $LOCAL_HTTPS_PORT $REMOTE_HTTP_PORT $REMOTE_HTTPS_PORT; do
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            log_event "ERROR" "Invalid port number: $port"
            errors=$((errors + 1))
        fi
    done

    return $errors
}

log_event() {
    local level="$1"
    local message="$2"

    # Validate parameters.
    if [ -z "$level" ]; then
        level="info"
    fi
    if [ -z "$message" ]; then
        message=""
    fi

    # Transform level to lowercase
    level=$(echo "$level" | tr '[:upper:]' '[:lower:]')

    # Validate level
    if [[ ! "$level" =~ ^(info|warning|error)$ ]]; then
        log_event "INFO" "Invalid log level: $level. Defaulting to 'info'."
        level="info"
    fi

    # Log the event
    echo "$(date '+%Y-%m-%d %H:%M:%S') $level $message" > /dev/stdout
}

# Show SSH public key.
show_public_key() {
    cat /ssh-tunnel/keys/tunnel_rsa_key.pub
    log_event "INFO" "Waiting 30 seconds before continuing..."
    sleep 30
}

# Function to start the tunnel.
start_tunnel() {
    log_event "INFO" "Starting SSH tunnel to $SSH_SERVER..."

    # Start autossh in background.
    autossh -M 0 -N \
        -o "ServerAliveInterval 30" \
        -o "ServerAliveCountMax 3" \
        -o "ExitOnForwardFailure=yes" \
        -o "StrictHostKeyChecking=accept-new" \
        -o "GatewayPorts=yes" \
        -o "PermitLocalCommand=yes" \
        -i /ssh-tunnel/keys/tunnel_rsa_key \
        -p $SSH_PORT \
        -R $REMOTE_HTTP_PORT:localhost:$LOCAL_HTTP_PORT \
        -R $REMOTE_HTTPS_PORT:localhost:$LOCAL_HTTPS_PORT \
        $SSH_USER@$SSH_SERVER -N &

    # Wait a few seconds for the tunnel to establish.
    sleep 5
}

# Function to check tunnel status.
check_tunnel() {

    # Check if autossh process is running
    if pgrep -f "autossh.*$SSH_SERVER" > /dev/null; then
        # Check local connectivity
        if nc -4 -z -w5 localhost $LOCAL_HTTP_PORT 2>/dev/null && nc -4 -z -w5 localhost $LOCAL_HTTPS_PORT 2>/dev/null; then
            SSH_TUNNEL_STATUS="ACTIVE"
            SSH_CONSECUTIVE_FAILURES=0
            return 0
        else
            log_event "WARNING" "Maybe the tunnel is failing. SSH (autossh) process running but ports are not accessible"
        fi
    fi

    # If we get here, the tunnel is down
    SSH_TUNNEL_STATUS="DOWN"
    SSH_CONSECUTIVE_FAILURES=$((SSH_CONSECUTIVE_FAILURES + 1))
    return 1
}

# Function for cleanup on exit/termination.
cleanup() {
    log_event "INFO" "Received termination signal. Cleaning up..."
    pkill -f "autossh.*$SSH_SERVER" 2>/dev/null || true
    exit 0
}

#
# Main process.
#

# Call validation before continuing
if ! validate_environment; then
    exit 1
fi

# Configure signal handling
trap cleanup SIGHUP SIGINT SIGTERM

# Ensure .ssh directory exists (temporary needed for ssh-copy-id).
mkdir -p ~/.ssh
touch ~/.ssh/known_hosts

# Pre-scan destination host to add it to known_hosts and avoid acceptance in prompt.
ssh-keyscan -p $SSH_PORT $SSH_SERVER >> ~/.ssh/known_hosts 2>/dev/null

# Check if SSH keys exist.
if [ ! -f /ssh-tunnel/keys/tunnel_rsa_key ]; then
    log_event "WARNING" "Public SSH key NOT found!"
    log_event "INFO" "Generating a new RSA key..."
    ssh-keygen -t rsa -b 4096 -f /ssh-tunnel/keys/tunnel_rsa_key -N "" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_event "ERROR" "Failed to generate SSH key. Exiting..."
        exit 1
    else
        log_event "INFO" "SSH key generated successfully!"
    fi
else
    log_event "INFO" "Public SSH key found!"
fi

# If password is provided, try to copy key automatically.
if [ ! -z "$SSH_PASSWORD" ]; then
    log_event "INFO" "Attempting to automatically copy the SSH key to the remote server using the provided SSH_PASSWORD..."

    # Use sshpass to copy key without user intervention.
    export SSHPASS=$SSH_PASSWORD

    # Copy the public key.
    sshpass -e ssh-copy-id -o StrictHostKeyChecking=accept-new -i /ssh-tunnel/keys/tunnel_rsa_key -p $SSH_PORT $SSH_USER@$SSH_SERVER > /dev/null 2>&1

    # Check if copy was successful.
    if [ $? -eq 0 ]; then
        log_event "INFO" "SSH key successfully copied to remote server."
    else
        log_event "WARNING" "Could not copy SSH key automatically. Please add the following public key manually:"
        show_public_key
    fi

    # Clean environment variable for security
    unset SSHPASS
    unset SSH_PASSWORD
    log_event "INFO" "SSH_PASSWORD variable unsetted for security reasons."
else
    log_event "WARNING" "SSH_PASSWORD variable is not set. If it's the first time you connect to $SSH_SERVER server, please add the following public key manually:"
    show_public_key
fi

# Start tunnel for the first time
start_tunnel

# Main monitoring loop
log_event "INFO" "Starting tunnel monitoring (checking every $SSH_CHECK_INTERVAL seconds)..."
while true; do
    # Check tunnel status.
    if ! check_tunnel; then
        log_event "WARNING" "SSH tunnel status: $SSH_TUNNEL_STATUS"
        log_event "WARNING" "Fail: $SSH_CONSECUTIVE_FAILURES/$SSH_MAX_FAILURES"

        # If too many consecutive failures, log critical event and exit.
        if [ $SSH_CONSECUTIVE_FAILURES -ge $SSH_MAX_FAILURES ]; then
            log_event "ERROR" "SSH tunnel to $SSH_SERVER failed after $SSH_MAX_FAILURES attempts. Manual intervention required. Exiting..."
            break
        fi

        log_event "INFO" "Attempting to restart the tunnel..."

        # Kill any residual processes.
        pkill -f "autossh.*$SSH_SERVER" 2>/dev/null || true
        sleep 5

        # Check that no zombie processes remain.
        if pgrep -f "autossh.*$SSH_SERVER" > /dev/null; then
            pkill -9 -f "autossh.*$SSH_SERVER" 2>/dev/null || true
            sleep 5
        fi

        # Restart tunnel
        start_tunnel
    else
        log_event "INFO" "SSH tunnel status: $SSH_TUNNEL_STATUS"
    fi

    # Wait the check interval before next verification.
    sleep $SSH_CHECK_INTERVAL
done

# Clean up on exit
cleanup
log_event "INFO" "SSH tunnel process terminated."
exit 0