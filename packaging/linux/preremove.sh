#!/bin/sh

set -e

service_name="bindplane-supervisor"

uninstall() {
     if command -v systemctl > /dev/null 2>&1; then
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            echo "Stopping service: $service_name"
            systemctl stop "$service_name" || true
        fi
        
        if systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
            echo "Disabling service: $service_name"
            systemctl disable "$service_name" || true
        fi
        
        echo "Reloading systemd daemon"
        systemctl daemon-reload || true
    fi
}

uninstall
