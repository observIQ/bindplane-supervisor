# Bindplane Supervisor — Project Specification

## Problem Statement

[Bindplane](https://bindplane.com/) manages OpenTelemetry Collectors remotely via the [OpAMP protocol](https://opentelemetry.io/docs/specs/opamp/). The upstream [OpenTelemetry OpAMP Supervisor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/opampsupervisor) implements this protocol, but it ships as a standalone binary with no packaging, no service registration, and no default configuration. Users must manually write a configuration file, install the binary, set up a system service, and wire everything to their Bindplane instance.

Bindplane Supervisor eliminates this setup burden. It takes the upstream supervisor binary and wraps it in platform-native packages (deb, rpm, msi, tar.gz, zip) with pre-configured defaults, system service registration, and one-command install scripts for Linux, macOS, and Windows.

## Goals

1. **Zero-config connection to Bindplane** — Install scripts accept an endpoint and secret key, then generate a working `supervisor-config.yaml` automatically.
2. **Platform-native packaging** — Deliver deb/rpm packages for Linux, an MSI for Windows, and tar.gz/zip archives for all platforms, each with proper service registration.
3. **Collector-agnostic** — Work with any OpenTelemetry Collector distribution. No collector is bundled; users supply their own via the install script or manual configuration.
4. **Version-aligned releases** — Each release of this project corresponds to the upstream OpenTelemetry OpAMP Supervisor version it packages (e.g., Bindplane Supervisor v0.120.0 packages upstream supervisor v0.120.0).
5. **Minimal maintenance surface** — No custom Go code. The repository is purely packaging infrastructure (GoReleaser config, install scripts, platform service definitions, and configuration templates).

## Non-Goals

- Bundling or distributing an OpenTelemetry Collector binary.
- Kubernetes deployment (out of scope; Bindplane has separate mechanisms for K8s).
- Custom patches or forks of the upstream supervisor binary.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Bindplane Server                   │
│                  (OpAMP endpoint)                     │
└──────────────────────┬──────────────────────────────┘
                       │ OpAMP (WebSocket)
                       │
┌──────────────────────▼──────────────────────────────┐
│              Bindplane Supervisor                     │
│  ┌─────────────────────────────────────────────┐     │
│  │  OpenTelemetry OpAMP Supervisor (upstream)   │     │
│  │  - Receives config from Bindplane            │     │
│  │  - Reports health, metrics, logs             │     │
│  │  - Manages collector lifecycle               │     │
│  └──────────────────────┬──────────────────────┘     │
│                         │ Process management          │
│  ┌──────────────────────▼──────────────────────┐     │
│  │  OpenTelemetry Collector (user-provided)     │     │
│  │  - Any distribution (contrib, custom, etc.)  │     │
│  │  - Configuration managed by supervisor       │     │
│  └─────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────┘
```

The supervisor sits between Bindplane and the collector. Bindplane sends configuration over OpAMP; the supervisor applies it to the collector and reports status back.

## Design Decisions

### No custom Go code

The upstream OpenTelemetry OpAMP Supervisor binary is used as-is. This project's value is in packaging and configuration, not in modifying the supervisor itself. This keeps the maintenance cost low and avoids divergence from upstream.

### Collector is not bundled

The supervisor manages a collector but does not include one. This is intentional:

- Users may already have a preferred collector distribution installed.
- Collector release cycles are independent of the supervisor's.
- Bundling would significantly increase package size and create version coupling.

The install scripts provide a `-c`/`--collector-url`/`-CollectorURL` flag to download a collector binary at install time as a convenience, but this is optional.

### Version alignment with upstream

Release tags (e.g., `v0.120.0`) correspond directly to the upstream OpenTelemetry OpAMP Supervisor version being packaged. The `SUPERVISOR_VERSION` environment variable during the release build controls which upstream version is fetched. This makes it clear to users exactly which supervisor version they are running.

### Pre-configured supervisor capabilities

The generated `supervisor-config.yaml` enables all OpAMP capabilities by default:

| Capability | Enabled | Purpose |
|---|---|---|
| `reports_effective_config` | Yes | Bindplane can view the active collector config |
| `reports_own_metrics` | Yes | Supervisor metrics visible in Bindplane |
| `reports_health` | Yes | Health status reporting |
| `reports_remote_config` | Yes | Confirms config receipt |
| `reports_own_logs` | Yes | Supervisor logs visible in Bindplane |
| `reports_heartbeat` | Yes | Liveness signal |
| `accepts_remote_config` | Yes | Bindplane can push collector configuration |
| `accepts_restart_command` | Yes | Bindplane can trigger collector restarts |
| `reports_available_components` | Yes | Reports which collector components are available |

This all-capabilities-enabled default is deliberate — it gives Bindplane full management authority over the collector, which is the primary use case.

### Dedicated service user on Linux

The Linux deb/rpm packages create a `bindplane-supervisor` system user and group during pre-install. The supervisor process runs as this non-root user. This follows the principle of least privilege and prevents the supervisor from having unnecessary system access.

### Platform service registration

Each platform uses its native service mechanism:

| Platform | Service Type | Service Name / Label |
|---|---|---|
| Linux | systemd (with init.d fallback) | `bindplane-supervisor` |
| macOS | LaunchDaemon | `com.bindplane.supervisor` |
| Windows | Windows Service (via MSI/WiX) | `bindplane-supervisor` |

All services are configured to:
- Start automatically on boot
- Restart on failure (with throttling to prevent restart loops)
- Set a file descriptor limit of 65,000 (needed for high-throughput collector configs)

### Install directory layout

Linux and macOS use `/opt/bindplane-supervisor/`; Windows uses `C:\Program Files\bindplane-supervisor\`. The layout is consistent across platforms:

```
<install-dir>/
├── supervisor(.exe)            # Upstream OpAMP Supervisor binary
├── supervisor-config.yaml      # Generated configuration
├── supervisor.log              # Supervisor log output
├── bin/
│   └── collector(.exe)         # User-provided collector binary (optional)
├── storage/                    # Collector working storage
└── supervisor_storage/         # Supervisor persistent state (instance ID, etc.)
```

Linux deb/rpm packages initially install to `/usr/share/bindplane-supervisor/` (per nfpm convention) and the post-install script relocates files to `/opt/bindplane-supervisor/`.

### Environment variables for collector compatibility

On Windows and macOS, the packaging sets environment variables consumed by some collector distributions:

| Variable | Value |
|---|---|
| `OIQ_OTEL_COLLECTOR_HOME` | Install directory |
| `OIQ_OTEL_COLLECTOR_STORAGE` | Storage subdirectory |

These are set system-wide on Windows (via WiX) and in the LaunchDaemon environment on macOS.

### Install scripts are standalone

The `install_unix.sh`, `install_darwin.sh`, and `install_windows.ps1` scripts are self-contained. They are published as release artifacts alongside the packages and can be `curl`-piped or downloaded independently. Each script handles:

1. Downloading and installing the supervisor package (or using a local file)
2. Generating `supervisor-config.yaml` from the provided endpoint and secret key
3. Optionally downloading a collector binary
4. Registering and starting the system service

The scripts also support `--uninstall` to cleanly remove all files and service registrations.

### Config file preservation

- Linux packages mark `supervisor-config.yaml` as `config|noreplace` in nfpm, so package upgrades do not overwrite a user-modified config.
- The Windows MSI sets `NeverOverwrite="yes"` on the config file component.
- The install scripts always regenerate the config (since they receive endpoint/secret-key as arguments), but package-manager-driven upgrades preserve it.

## Release Pipeline

Releases are triggered by pushing a `v*` git tag. The pipeline:

1. `make release-prep` downloads upstream supervisor binaries via `retrieve-supervisor.sh`, stages platform configs and packaging files into `release_deps/`
2. GoReleaser Pro builds all artifacts (archives, deb, rpm, msi) from the staged `release_deps/`
3. All artifacts plus install scripts and SHA256 checksums are published as a GitHub prerelease

### Artifact Matrix

| Format | Linux amd64 | Linux arm64 | macOS amd64 | macOS arm64 | Windows amd64 |
|---|---|---|---|---|---|
| tar.gz | Yes | Yes | Yes | Yes | — |
| zip | — | — | — | — | Yes |
| deb | Yes | Yes | — | — | — |
| rpm | Yes | Yes | — | — | — |
| msi | — | — | — | — | Yes |

Windows arm64 is not supported (the upstream supervisor does not publish a Windows arm64 binary).
