#!/bin/bash
set -e

if [ "$(ls -A /home/ubuntu)" = "lost+found" ]; then
    echo "Populating /home/ubuntu with default skeleton..."
    cp -r /etc/skel/. /home/ubuntu/
    chown -R ubuntu:ubuntu /home/ubuntu
fi
