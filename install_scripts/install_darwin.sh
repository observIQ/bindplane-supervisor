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

# Supervisor's installation directory
: "${BINDPLANE_SUPERVISOR_INSTALL_DIR:=/opt/bindplane-supervisor}"

# Default collector binary path
: "${BINDPLANE_COLLECTOR_BIN:=/opt/bindplane-supervisor/bin/collector}"

# Supervisor config file path
: "${BINDPLANE_SUPERVISOR_CONFIG:=${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor-config.yaml}"

# LaunchDaemon plist
PLIST_LABEL="com.bindplane.supervisor"
PLIST_PATH="/Library/LaunchDaemons/${PLIST_LABEL}.plist"

# Script arguments
DOWNLOAD_URL=""
FILE_PATH=""
COLLECTOR_URL=""
BINDPLANE_ENDPOINT=""
BINDPLANE_SECRET_KEY=""

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --download-url <url>   URL to download the supervisor tar.gz archive
  --file-path <path>     Path to a local supervisor tar.gz archive or binary
  --collector-url <url>  URL to download the collector binary
  --endpoint <url>       (required) Bindplane endpoint URL (e.g. wss://app.bindplane.com/v1/opamp)
  --secret-key <key>     (required) Bindplane secret key for authentication

If neither --download-url nor --file-path is provided, the script
checks for an existing installation and errors if none is found.
EOF
    exit 1
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --download-url)
                if [ -z "$2" ]; then
                    echo "Error: --download-url requires a value" >&2
                    exit 1
                fi
                DOWNLOAD_URL="$2"
                shift 2
                ;;
            --file-path)
                if [ -z "$2" ]; then
                    echo "Error: --file-path requires a value" >&2
                    exit 1
                fi
                FILE_PATH="$2"
                shift 2
                ;;
            --collector-url)
                if [ -z "$2" ]; then
                    echo "Error: --collector-url requires a value" >&2
                    exit 1
                fi
                COLLECTOR_URL="$2"
                shift 2
                ;;
            --endpoint)
                if [ -z "$2" ]; then
                    echo "Error: --endpoint requires a value" >&2
                    exit 1
                fi
                BINDPLANE_ENDPOINT="$2"
                shift 2
                ;;
            --secret-key)
                if [ -z "$2" ]; then
                    echo "Error: --secret-key requires a value" >&2
                    exit 1
                fi
                BINDPLANE_SECRET_KEY="$2"
                shift 2
                ;;
            *)
                echo "Error: unknown option '$1'" >&2
                usage
                ;;
        esac
    done

    if [ -n "$DOWNLOAD_URL" ] && [ -n "$FILE_PATH" ]; then
        echo "Error: --download-url and --file-path are mutually exclusive" >&2
        exit 1
    fi

    if [ -z "$BINDPLANE_ENDPOINT" ]; then
        echo "Error: --endpoint is required" >&2
        exit 1
    fi

    if [ -z "$BINDPLANE_SECRET_KEY" ]; then
        echo "Error: --secret-key is required" >&2
        exit 1
    fi
}

check_requirements() {
    if [ -n "$DOWNLOAD_URL" ] || [ -n "$COLLECTOR_URL" ]; then
        if ! command -v curl > /dev/null 2>&1; then
            echo "Error: curl is required for downloading but was not found" >&2
            exit 1
        fi
    fi
}

install_supervisor_from_file() {
    file="$1"

    echo "Installing supervisor from: $file"
    mkdir -p "${BINDPLANE_SUPERVISOR_INSTALL_DIR}"

    # Strip query parameters for file type detection
    file_path="${file%%\?*}"

    case "$file_path" in
        *.tar.gz|*.tgz)
            echo "Extracting tar.gz archive..."
            tar -xzf "$file" -C "${BINDPLANE_SUPERVISOR_INSTALL_DIR}" --strip-components=0
            ;;
        *.zip)
            echo "Extracting zip archive..."
            unzip -o "$file" -d "${BINDPLANE_SUPERVISOR_INSTALL_DIR}"
            ;;
        *)
            cp "$file" "${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor"
            chmod 755 "${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor"
            ;;
    esac

    echo "Supervisor installed successfully"
}

download_and_install_supervisor() {
    url="$1"

    tmp_dir=$(mktemp -d)
    # Strip query parameters for file type detection
    url_path="${url%%\?*}"

    case "$url_path" in
        *.tar.gz|*.tgz)
            tmp_file="${tmp_dir}/supervisor_download.tar.gz"
            ;;
        *.zip)
            tmp_file="${tmp_dir}/supervisor_download.zip"
            ;;
        *)
            tmp_file="${tmp_dir}/supervisor_download"
            ;;
    esac

    echo "Downloading supervisor from: $url"
    curl -fSL -o "$tmp_file" "$url"
    echo "Download complete"

    install_supervisor_from_file "$tmp_file"
    rm -rf "$tmp_dir"
}

check_service_installed() {
    if [ -f "$PLIST_PATH" ]; then
        echo "Existing installation found (LaunchDaemon plist)"
        return 0
    fi

    if [ -x "${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor" ]; then
        echo "Existing installation found (supervisor binary)"
        return 0
    fi

    echo "Error: no existing bindplane-supervisor installation found" >&2
    echo "Use --download-url or --file-path to install a package" >&2
    exit 1
}

# install_plist resolves the [INSTALLDIR] placeholders in the plist
# included in the supervisor archive and installs it to /Library/LaunchDaemons/.
install_plist() {
    src_plist="${BINDPLANE_SUPERVISOR_INSTALL_DIR}/${PLIST_LABEL}.plist"

    if [ ! -f "$src_plist" ]; then
        echo "Error: plist not found at $src_plist" >&2
        exit 1
    fi

    echo "Installing LaunchDaemon plist to $PLIST_PATH"
    sed "s|\[INSTALLDIR\]|${BINDPLANE_SUPERVISOR_INSTALL_DIR}|g" "$src_plist" > "$PLIST_PATH"
    chmod 644 "$PLIST_PATH"
    rm -f "$src_plist"
    echo "LaunchDaemon plist installed successfully"
}

stop_service() {
    echo "Stopping bindplane-supervisor service..."
    if launchctl list "$PLIST_LABEL" > /dev/null 2>&1; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
    fi
}

start_service() {
    echo "Starting bindplane-supervisor service..."
    launchctl load "$PLIST_PATH"
}

# update_supervisor_config writes the supervisor configuration file with
# the provided Bindplane endpoint and secret key.
update_supervisor_config() {
    config_file="$BINDPLANE_SUPERVISOR_CONFIG"

    echo "Writing supervisor config to $config_file"
    cat << EOF > "$config_file"
# Bindplane Supervisor Configuration for macOS
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

# Main
parse_args "$@"
check_requirements

# Supervisor installation
if [ -n "$DOWNLOAD_URL" ]; then
    download_and_install_supervisor "$DOWNLOAD_URL"
elif [ -n "$FILE_PATH" ]; then
    install_supervisor_from_file "$FILE_PATH"
else
    check_service_installed
fi

# Create required directories
mkdir -p "${BINDPLANE_SUPERVISOR_INSTALL_DIR}/storage"
mkdir -p "${BINDPLANE_SUPERVISOR_INSTALL_DIR}/supervisor_storage"

# Stop the service before modifying config or collector binary.
# A previous installation may have started it.
stop_service

# Install the LaunchDaemon plist (with resolved paths)
install_plist

# Supervisor config update
update_supervisor_config

# Collector download
if [ -n "$COLLECTOR_URL" ]; then
    install_collector "$COLLECTOR_URL"
fi

# Start the service with the updated config and collector
start_service
