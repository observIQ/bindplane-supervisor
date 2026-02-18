# Bindplane Supervisor

<center>

[![Action Status](https://github.com/observIQ/supervisor/workflows/Build/badge.svg)](https://github.com/observIQ/supervisor/actions)
[![Action Test Status](https://github.com/observIQ/supervisor/workflows/Tests/badge.svg)](https://github.com/observIQ/supervisor/actions)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

</center>

Bindplane Supervisor is a distribution of the [OpenTelemetry Supervisor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/opampsupervisor) that is packaged and configured to connect to [Bindplane](https://bindplane.com/). It manages an OpenTelemetry Collector of your choice, allowing Bindplane to remotely configure and monitor the collector instance.

## Features

- Connects to BindPlane OP via the OpAMP protocol
- Manages a user-specified OpenTelemetry Collector
- Supports remote configuration updates from BindPlane
- Health monitoring and status reporting
- Automatic collector restarts on configuration changes

## Quick Start

### Installation

#### Linux

**Prerequisites:** root access, `curl`, `dpkg` or `rpm`

Install from the latest release:

```sh
sudo curl -fSL https://github.com/observIQ/supervisor/releases/latest/download/install_unix.sh | sudo sh -s -- \
  --endpoint "wss://app.bindplane.com/v1/opamp" \
  --secret-key "YOUR_SECRET_KEY"
```

Install a specific version (automatically detects architecture and package manager):

```sh
sudo sh install_unix.sh \
  -e "wss://app.bindplane.com/v1/opamp" \
  -s "YOUR_SECRET_KEY" \
  -v "v0.145.0"
```

Install a specific version with a collector binary:

```sh
sudo sh install_unix.sh \
  -v "v0.145.0" \
  -c "https://example.com/otelcol-contrib" \
  -e "wss://app.bindplane.com/v1/opamp" \
  -s "YOUR_SECRET_KEY"
```

Install from a specific download URL:

```sh
sudo sh install_unix.sh \
  -e "wss://app.bindplane.com/v1/opamp" \
  -s "YOUR_SECRET_KEY" \
  -d "https://github.com/observIQ/supervisor/releases/download/v1.0.0/bindplane-supervisor_1.0.0_linux_amd64.deb"
```

Install from a local package file:

```sh
sudo sh install_unix.sh \
  -e "wss://app.bindplane.com/v1/opamp" \
  -s "YOUR_SECRET_KEY" \
  -f "./bindplane-supervisor_1.0.0_linux_amd64.deb"
```

Install with a collector binary:

```sh
sudo sh install_unix.sh \
  -e "wss://app.bindplane.com/v1/opamp" \
  -s "YOUR_SECRET_KEY" \
  -d "https://github.com/observIQ/supervisor/releases/download/v1.0.0/bindplane-supervisor_1.0.0_linux_amd64.deb" \
  -c "https://example.com/otelcol-contrib"
```

Uninstall:

```sh
sudo sh install_unix.sh --uninstall
```

> **Note:** The install script installs Bindplane Supervisor as a systemd service. Configuration is written to `/opt/bindplane-supervisor/supervisor-config.yaml`.

#### macOS

**Prerequisites:** root access, `curl`

Install from the latest release:

```sh
sudo curl -fSL https://github.com/observIQ/supervisor/releases/latest/download/install_darwin.sh | sudo sh -s -- \
  --endpoint "wss://app.bindplane.com/v1/opamp" \
  --secret-key "YOUR_SECRET_KEY"
```

Install a specific version (automatically detects architecture):

```sh
sudo sh install_darwin.sh \
  -e "wss://app.bindplane.com/v1/opamp" \
  -s "YOUR_SECRET_KEY" \
  -v "v0.145.0"
```

Install a specific version with a collector binary:

```sh
sudo sh install_darwin.sh \
  -v "v0.145.0" \
  -c "https://example.com/otelcol-contrib" \
  -e "wss://app.bindplane.com/v1/opamp" \
  -s "YOUR_SECRET_KEY"
```

Install from a specific download URL:

```sh
sudo sh install_darwin.sh \
  -e "wss://app.bindplane.com/v1/opamp" \
  -s "YOUR_SECRET_KEY" \
  -d "https://github.com/observIQ/supervisor/releases/download/v1.0.0/bindplane-supervisor_1.0.0_darwin_arm64.tar.gz"
```

Install from a local file:

```sh
sudo sh install_darwin.sh \
  -e "wss://app.bindplane.com/v1/opamp" \
  -s "YOUR_SECRET_KEY" \
  -f "./bindplane-supervisor_1.0.0_darwin_arm64.tar.gz"
```

Install with a collector binary:

```sh
sudo sh install_darwin.sh \
  -e "wss://app.bindplane.com/v1/opamp" \
  -s "YOUR_SECRET_KEY" \
  -d "https://github.com/observIQ/supervisor/releases/download/v1.0.0/bindplane-supervisor_1.0.0_darwin_arm64.tar.gz" \
  -c "https://example.com/otelcol-contrib"
```

Uninstall:

```sh
sudo sh install_darwin.sh --uninstall
```

> **Note:** The install script registers a LaunchDaemon (`com.bindplane.supervisor`). Configuration is written to `/opt/bindplane-supervisor/supervisor-config.yaml`.

#### Windows

**Prerequisites:** Administrator PowerShell, .NET Framework with TLS 1.2 support

Install a specific version (automatically detects architecture):

```powershell
.\install_windows.ps1 `
  -Endpoint "wss://app.bindplane.com/v1/opamp" `
  -SecretKey "YOUR_SECRET_KEY" `
  -Version "v0.145.0"
```

Install a specific version with a collector binary:

```powershell
.\install_windows.ps1 `
  -Version "v0.145.0" `
  -CollectorURL "https://example.com/otelcol-contrib.exe" `
  -Endpoint "wss://app.bindplane.com/v1/opamp" `
  -SecretKey "YOUR_SECRET_KEY"
```

Install from a download URL:

```powershell
.\install_windows.ps1 `
  -Endpoint "wss://app.bindplane.com/v1/opamp" `
  -SecretKey "YOUR_SECRET_KEY" `
  -DownloadURL "https://github.com/observIQ/supervisor/releases/download/v1.0.0/bindplane-supervisor_1.0.0_windows_amd64.msi"
```

Install from a local MSI file:

```powershell
.\install_windows.ps1 `
  -Endpoint "wss://app.bindplane.com/v1/opamp" `
  -SecretKey "YOUR_SECRET_KEY" `
  -FilePath ".\bindplane-supervisor_1.0.0_windows_amd64.msi"
```

Install with a collector binary:

```powershell
.\install_windows.ps1 `
  -Endpoint "wss://app.bindplane.com/v1/opamp" `
  -SecretKey "YOUR_SECRET_KEY" `
  -DownloadURL "https://github.com/observIQ/supervisor/releases/download/v1.0.0/bindplane-supervisor_1.0.0_windows_amd64.msi" `
  -CollectorURL "https://example.com/otelcol-contrib.exe"
```

Uninstall:

```powershell
.\install_windows.ps1 -Uninstall
```

> **Note:** The install script installs an MSI package and registers a Windows service (`bindplane-supervisor`). Configuration is written to `C:\Program Files\bindplane-supervisor\supervisor-config.yaml`.

### Script Flags Reference

| Flag (Unix) | Flag (PowerShell) | Required | Description |
|---|---|---|---|
| `-e, --endpoint` | `-Endpoint` | Yes | Bindplane endpoint URL |
| `-s, --secret-key` | `-SecretKey` | Yes | Bindplane secret key |
| `-v, --version` | `-Version` | No | Release version to install (e.g. `v0.145.0`) |
| `-c, --collector-url` | `-CollectorURL` | No | URL to download the collector binary |
| `-d, --download-url` | `-DownloadURL` | No | URL to download the supervisor package |
| `-f, --file-path` | `-FilePath` | No | Path to a local package file |
| `--uninstall` | `-Uninstall` | No | Uninstall and remove all files |

> **Note:** `-v`, `-d`, and `-f` are mutually exclusive — only one may be provided at a time.

## Configuration

The install scripts automatically generate a `supervisor-config.yaml` file with the provided endpoint and secret key. The generated config includes:

- **Server connection** — OpAMP endpoint URL and authentication headers
- **Capabilities** — Reporting and remote config acceptance flags
- **Agent** — Path to the managed OpenTelemetry Collector executable
- **Storage** — Directory for persistent supervisor state
- **Telemetry** — Log level and output paths

The config file location depends on the platform:

| Platform | Config Directory |
|---|---|
| Linux | `/opt/bindplane-supervisor/` |
| macOS | `/opt/bindplane-supervisor/` |
| Windows | `C:\Program Files\bindplane-supervisor\` |

For advanced configuration options, see the upstream [OpenTelemetry OpAMP Supervisor documentation](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/opampsupervisor).

# Community

Bindplane Supervisor is an open source project. If you'd like to contribute, take a look at our [contribution guidelines](/docs/CONTRIBUTING.md) and [developer guide](/docs/development.md). We look forward to building with you.

# How can we help?

If you need any additional help feel free to file a GitHub issue or reach out to us at support@observiq.com.
