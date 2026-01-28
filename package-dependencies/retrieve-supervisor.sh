#!/bin/sh
# Copyright observIQ, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script retrieves supervisor binaries from the OpenTelemetry Collector Releases repository.
# https://github.com/open-telemetry/opentelemetry-collector-releases
#
# The binaries are placed in the directory specified by $BIN_DIR.
# If not specified, the binaries are placed in a directory called "supervisor-binaries" in the root of the repository.
# If the directory does not exist, it is created.
#
# The version of the supervisor to retrieve is specified by $SUPERVISOR_VERSION.
# If not specified, the latest version is retrieved.
set -e

# Check if the BIN_DIR is specified
if [ -z "$BIN_DIR" ]; then
    BASEDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
    PROJECT_BASE="$BASEDIR/.."
    BIN_DIR="$PROJECT_BASE/supervisor-binaries"
fi

# Create a clean directory for the supervisor binaries
rm -rf "$BIN_DIR" && mkdir -p "$BIN_DIR"

# Check if the SUPERVISOR_VERSION is specified
if [ -z "$SUPERVISOR_VERSION" ] || [ "$SUPERVISOR_VERSION" = "latest" ]; then
    # Get the latest version of OTel which will align with the latest supervisor version
    echo "Getting the latest version of OTel"
    SUPERVISOR_VERSION=$(curl -s https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases/latest | jq -r '.tag_name')
    if [ -z "$SUPERVISOR_VERSION" ]; then
        echo "Failed to get the latest version of OTel"
        exit 1
    fi
fi

# Remove 'v' prefix from SUPERVISOR_VERSION if it exists
SUPERVISOR_VERSION=$(echo $SUPERVISOR_VERSION | sed 's/v//')
echo "Using supervisor version: $SUPERVISOR_VERSION"

# Retrieve the supervisor binaries
# Base URL for the releases (note: tag contains slashes which need to be URL-encoded)
BASE_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/cmd%2Fopampsupervisor%2Fv${SUPERVISOR_VERSION}"

# Define the platforms we need to download
PLATFORMS="windows_amd64.exe linux_amd64 linux_arm64 darwin_arm64 darwin_amd64"

for PLATFORM in $PLATFORMS; do
    DOWNLOAD_BINARY_NAME="opampsupervisor_${SUPERVISOR_VERSION}_${PLATFORM}"
    BINARY_NAME="supervisor_${PLATFORM}"
    DOWNLOAD_URL="${BASE_URL}/${DOWNLOAD_BINARY_NAME}"
    OUTPUT_FILE="${BIN_DIR}/${BINARY_NAME}"

    echo "Downloading ${BINARY_NAME}..."
    if curl -fSL -o "$OUTPUT_FILE" "$DOWNLOAD_URL"; then
        echo "Successfully downloaded ${BINARY_NAME}"
    else
        echo "Failed to download ${BINARY_NAME}"
        exit 1
    fi
done

echo "All supervisor binaries downloaded to ${BIN_DIR}"
