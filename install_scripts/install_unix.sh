#!/bin/sh
# Copyright  observIQ, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root" >&2
    exit 1
fi

# Read optional package overrides. Users should deploy the override
# file before installing for the first time. The override should
# not be modified unless uninstalling and re-installing.
[ -f /etc/default/bindplane-supervisor ] && . /etc/default/bindplane-supervisor
[ -f /etc/sysconfig/bindplane-supervisor ] && . /etc/sysconfig/bindplane-supervisor

# Supervisor's installation directory
: "${BINDPLANE_SUPERVISOR_INSTALL_DIR:=/opt/bindplane-supervisor}"

# Default collector binary path
: "${BINDPLANE_COLLECTOR_BIN:=/opt/bindplane-supervisor/bin/collector}"

# Supervisor config file path
: "${BINDPLANE_SUPERVISOR_CONFIG:=${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor-config.yaml}"

# Script arguments
DOWNLOAD_URL=""
FILE_PATH=""
COLLECTOR_URL=""
BINDPLANE_ENDPOINT=""
BINDPLANE_SECRET_KEY=""
UNINSTALL=""

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --uninstall                Uninstall bindplane-supervisor and remove all associated files
  -d, --download-url <url>   URL to download the supervisor deb/rpm package
  -f, --file-path <path>     Path to a local deb/rpm package file
  -c, --collector-url <url>  URL to download the collector binary
  -e, --endpoint <url>       (required for install) Bindplane endpoint URL (e.g. wss://app.bindplane.com/v1/opamp)
  -s, --secret-key <key>     (required for install) Bindplane secret key for authentication

If neither --download-url (-d) nor --file-path (-f) is provided, the script
checks for an existing installation and errors if none is found.
EOF
    exit 1
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--download-url)
                if [ -z "$2" ]; then
                    echo "Error: $1 requires a value" >&2
                    exit 1
                fi
                DOWNLOAD_URL="$2"
                shift 2
                ;;
            -f|--file-path)
                if [ -z "$2" ]; then
                    echo "Error: $1 requires a value" >&2
                    exit 1
                fi
                FILE_PATH="$2"
                shift 2
                ;;
            -c|--collector-url)
                if [ -z "$2" ]; then
                    echo "Error: $1 requires a value" >&2
                    exit 1
                fi
                COLLECTOR_URL="$2"
                shift 2
                ;;
            -e|--endpoint)
                if [ -z "$2" ]; then
                    echo "Error: $1 requires a value" >&2
                    exit 1
                fi
                BINDPLANE_ENDPOINT="$2"
                shift 2
                ;;
            -s|--secret-key)
                if [ -z "$2" ]; then
                    echo "Error: $1 requires a value" >&2
                    exit 1
                fi
                BINDPLANE_SECRET_KEY="$2"
                shift 2
                ;;
            --uninstall)
                UNINSTALL=true
                shift 1
                ;;
            *)
                echo "Error: unknown option '$1'" >&2
                usage
                ;;
        esac
    done

    if [ "$UNINSTALL" = true ]; then
        return
    fi

    if [ -n "$DOWNLOAD_URL" ] && [ -n "$FILE_PATH" ]; then
        echo "Error: --download-url (-d) and --file-path (-f) are mutually exclusive" >&2
        exit 1
    fi

    if [ -z "$BINDPLANE_ENDPOINT" ]; then
        echo "Error: --endpoint (-e) is required" >&2
        exit 1
    fi

    if [ -z "$BINDPLANE_SECRET_KEY" ]; then
        echo "Error: --secret-key (-s) is required" >&2
        exit 1
    fi
}

detect_package_manager() {
    if command -v dpkg > /dev/null 2>&1; then
        echo "deb"
    elif command -v rpm > /dev/null 2>&1; then
        echo "rpm"
    else
        echo "Error: neither dpkg nor rpm found" >&2
        exit 1
    fi
}

package_type_from_file() {
    file="$1"
    case "$file" in
        *.deb)
            echo "deb"
            ;;
        *.rpm)
            echo "rpm"
            ;;
        *)
            echo "Error: unsupported package type for file '$file'" >&2
            exit 1
            ;;
    esac
}

install_package() {
    file="$1"
    pkg_type=$(package_type_from_file "$file")

    echo "Installing package: $file"
    case "$pkg_type" in
        deb)
            dpkg -i --force-confold "$file"
            ;;
        rpm)
            rpm -U "$file"
            ;;
    esac
    echo "Package installed successfully"
}

download_and_install_package() {
    url="$1"
    pkg_type=$(detect_package_manager)

    tmp_dir=$(mktemp -d)
    tmp_file="${tmp_dir}/bindplane-supervisor.${pkg_type}"

    echo "Downloading package from: $url"
    curl -fSL -o "$tmp_file" "$url"
    echo "Download complete"

    install_package "$tmp_file"
    rm -rf "$tmp_dir"
}

check_service_installed() {
    if [ -f /etc/systemd/system/bindplane-supervisor.service ]; then
        echo "Existing installation found (systemd service)"
        return 0
    fi

    if [ -f /etc/init.d/bindplane-supervisor ]; then
        echo "Existing installation found (init.d service)"
        return 0
    fi

    if [ -x "${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor" ]; then
        echo "Existing installation found (supervisor binary)"
        return 0
    fi

    echo "Error: no existing bindplane-supervisor installation found" >&2
    echo "Use --download-url (-d) or --file-path (-f) to install a package" >&2
    exit 1
}

check_requirements() {
    if [ -n "$DOWNLOAD_URL" ] || [ -n "$COLLECTOR_URL" ]; then
        if ! command -v curl > /dev/null 2>&1; then
            echo "Error: curl is required for downloading but was not found" >&2
            exit 1
        fi
    fi
}

stop_service() {
    echo "Stopping bindplane-supervisor service..."
    if command -v systemctl > /dev/null 2>&1; then
        systemctl stop bindplane-supervisor 2>/dev/null || true
    elif [ -f /etc/init.d/bindplane-supervisor ]; then
        /etc/init.d/bindplane-supervisor stop 2>/dev/null || true
    fi
}

start_service() {
    echo "Starting bindplane-supervisor service..."
    if command -v systemctl > /dev/null 2>&1; then
        systemctl start bindplane-supervisor
    elif [ -f /etc/init.d/bindplane-supervisor ]; then
        /etc/init.d/bindplane-supervisor start
    else
        echo "Warning: could not detect init system, service not started" >&2
    fi
}

# update_supervisor_config writes the supervisor configuration file with
# the provided Bindplane endpoint and secret key.
update_supervisor_config() {
    config_file="$BINDPLANE_SUPERVISOR_CONFIG"

    echo "Writing supervisor config to $config_file"
    cat << EOF > "$config_file"
# Bindplane Supervisor Configuration for Linux
# Documentation: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/opampsupervisor

# OpAMP server connection settings
server:
  # Bindplane SaaS endpoint
  endpoint: "${BINDPLANE_ENDPOINT}"
  headers:
    # Replace with your Bindplane secret key from the Bindplane UI
    "X-Bindplane-Authorization": "Secret-Key ${BINDPLANE_SECRET_KEY}"

# Supervisor capabilities reported to the OpAMP server
capabilities:
  reports_effective_config: true
  reports_own_metrics: true
  reports_health: true
  reports_remote_config: true
  reports_own_logs: true
  reports_heartbeat: true
  accepts_remote_config: true
  accepts_restart_command: true
  reports_available_components: true

# Managed OpenTelemetry Collector configuration
agent:
  # Path to your OpenTelemetry Collector executable
  executable: "${BINDPLANE_COLLECTOR_BIN}"

# Persistent storage for supervisor state
storage:
  directory: "${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor_storage"

# Supervisor telemetry settings
telemetry:
  logs:
    level: info
    output_paths:
      - "${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor.log"
EOF

    echo "Supervisor config updated successfully"
}

install_collector() {
    url="$1"
    collector_dir=$(dirname "$BINDPLANE_COLLECTOR_BIN")
    echo "Installing collector binary to: $BINDPLANE_COLLECTOR_BIN"
    mkdir -p "$collector_dir"

    tmp_dir=$(mktemp -d)
    tmp_file="${tmp_dir}/collector_download"

    echo "Downloading collector from: $url"
    curl -fSL -o "$tmp_file" "$url"

    # Strip query parameters for file type detection
    url_path="${url%%\?*}"

    case "$url_path" in
        *.tar.gz|*.tgz)
            echo "Extracting tar.gz archive..."
            tar -xzf "$tmp_file" -C "$tmp_dir" --strip-components=0
            rm -f "$tmp_file"
            found=$(find "$tmp_dir" -type f | head -1)
            mv "$found" "$BINDPLANE_COLLECTOR_BIN"
            ;;
        *)
            mv "$tmp_file" "$BINDPLANE_COLLECTOR_BIN"
            ;;
    esac

    rm -rf "$tmp_dir"
    chmod 755 "$BINDPLANE_COLLECTOR_BIN"
    echo "Collector installed successfully"
}

uninstall_supervisor() {
    echo "Uninstalling bindplane-supervisor..."

    stop_service

    # Attempt package manager removal first
    if dpkg -s bindplane-supervisor 2>/dev/null | grep -q "Status:.*installed"; then
        echo "Removing deb package..."
        dpkg --purge bindplane-supervisor
    elif rpm -q bindplane-supervisor 2>/dev/null; then
        echo "Removing rpm package..."
        rpm -e bindplane-supervisor
    else
        echo "No deb/rpm package found, removing service definitions manually..."
        if command -v systemctl > /dev/null 2>&1; then
            systemctl disable bindplane-supervisor 2>/dev/null || true
            rm -f /etc/systemd/system/bindplane-supervisor.service
            rm -rf /etc/systemd/system/bindplane-supervisor.service.d
            systemctl daemon-reload
        fi
        if [ -f /etc/init.d/bindplane-supervisor ]; then
            rm -f /etc/init.d/bindplane-supervisor
        fi
    fi

    # Remove collector binary
    rm -f "${BINDPLANE_COLLECTOR_BIN}"

    # Remove install directory
    rm -rf "${BINDPLANE_SUPERVISOR_INSTALL_DIR}"

    # Remove environment override files
    rm -f /etc/default/bindplane-supervisor
    rm -f /etc/sysconfig/bindplane-supervisor

    echo "bindplane-supervisor has been uninstalled successfully"
}

# Main
parse_args "$@"

if [ "$UNINSTALL" = true ]; then
    uninstall_supervisor
    exit 0
fi

check_requirements

# Supervisor installation
if [ -n "$DOWNLOAD_URL" ]; then
    download_and_install_package "$DOWNLOAD_URL"
elif [ -n "$FILE_PATH" ]; then
    install_package "$FILE_PATH"
else
    check_service_installed
fi

# Stop the service before modifying config or collector binary.
# The package postinstall or a previous enable may have started it.
stop_service

# Supervisor config update
update_supervisor_config

# Collector download
if [ -n "$COLLECTOR_URL" ]; then
    install_collector "$COLLECTOR_URL"
fi

# Start the service with the updated config and collector
start_service
