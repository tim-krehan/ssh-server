#!/bin/bash
set -e

# Trap SIGINT and SIGTERM to terminate the process gracefully
trap "echo 'Signal received. Terminating process...'; exit 0" SIGINT SIGTERM

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

echo "Starting entrypoint script..."
# Generate SSH host keys if they do not exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host RSA key..."
    ssh-keygen -A
fi

# Verify SSH host keys were generated successfully
if [ ! -f /etc/ssh/ssh_host_rsa_key ] || [ ! -f /etc/ssh/ssh_host_ecdsa_key ] || [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    echo "Error: One or more SSH host keys could not be generated. Exiting."
    exit 1
fi

# Populate /home/ubuntu if necessary
/usr/local/bin/populate_home.sh

echo "Starting sshd..."
# Check if AUTHORIZED_KEYS is set and configure authorized keys for ubuntu user
if [ -n "$AUTHORIZED_KEYS" ]; then
    echo "Configuring authorized keys for ubuntu user..."
    mkdir -p /home/ubuntu/.ssh
    echo "Adding $(echo "$AUTHORIZED_KEYS" | wc -l) authorized keys."
    echo "$AUTHORIZED_KEYS" > /home/ubuntu/.ssh/authorized_keys
    chmod 700 /home/ubuntu/.ssh
    chmod 600 /home/ubuntu/.ssh/authorized_keys
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh
fi

echo "Starting sshd service..."
# Forward signals to the child process
exec "$@" &
child_pid=$!

# Wait for the child process and handle signals
wait $child_pid