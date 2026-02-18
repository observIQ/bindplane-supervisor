# Development

## Requirements

- [Go](https://go.dev/) (for the `addlicense` tool)
- [GoReleaser Pro](https://goreleaser.com/) v2.8.2+
- `make`, `curl`, `jq`

Install the Go-based tooling:

```sh
make install-tools
```

## Local Build

This repository does not contain custom Go source code. It packages pre-built [OpenTelemetry OpAMP Supervisor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/opampsupervisor) binaries into platform-specific packages (deb, rpm, msi, tar.gz, zip) along with configuration files and install scripts.

To run a full local release build in snapshot mode:

```sh
make release-test
```

This executes GoReleaser with `--snapshot`, producing all release artifacts in the `dist/` directory without publishing.

To clean all build artifacts:

```sh
make clean
```

This removes `release_deps/`, `supervisor-binaries/`, and `dist/`.

## Testing

### Local release testing

```sh
make release-test
```

This runs the full GoReleaser pipeline locally in snapshot mode, validating that all packages build correctly.

### CI

The `release-test.yml` GitHub Actions workflow runs `make release-test` on pull requests to verify the release pipeline.

### License headers

Check that all source files have the required Apache 2.0 license header:

```sh
make check-license
```

Automatically add missing license headers:

```sh
make add-license
```

## Release Process

Releases are triggered by pushing a `v*` git tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

### Pipeline

1. **`make release-prep`** — Prepares the `release_deps/` directory for linux/darwin:
   - Downloads upstream linux/darwin OpenTelemetry OpAMP Supervisor binaries via `retrieve-supervisor/retrieve-supervisor.sh` (from [opentelemetry-collector-releases](https://github.com/open-telemetry/opentelemetry-collector-releases))
   - Copies platform-specific config templates from `configs/` into `release_deps/{darwin,linux}/`
   - Copies packaging files from `packaging/` into `release_deps/{darwin,linux}/`
2. **`make release-prep-windows`** — Prepares the `release_deps/` directory for windows:
   - Downloads the upstream windows OpenTelemetry OpAMP Supervisor binary via `retrieve-supervisor/retrieve-supervisor-windows.sh`
   - Copies windows config templates from `configs/` into `release_deps/windows/`
   - Copies packaging files from `packaging/` into `release_deps/windows/`
   - Writes `VERSION.txt` and copies `LICENSE`
2. **GoReleaser build** — Builds all archives, native packages, and MSI installers from the prepared `release_deps/`
3. **GitHub prerelease** — Publishes all artifacts as a GitHub prerelease

### Upstream supervisor version

The `SUPERVISOR_VERSION` environment variable controls which upstream supervisor version is downloaded. If unset or set to `latest`, the script fetches the latest release from the OpenTelemetry Collector Releases repository.

```sh
SUPERVISOR_VERSION=v0.120.0 make release-test
```

### Release artifacts

| Artifact | Platforms |
|---|---|
| `bindplane-supervisor_*_linux_amd64.tar.gz` | Linux amd64 |
| `bindplane-supervisor_*_linux_arm64.tar.gz` | Linux arm64 |
| `bindplane-supervisor_*_darwin_amd64.tar.gz` | macOS amd64 |
| `bindplane-supervisor_*_darwin_arm64.tar.gz` | macOS arm64 |
| `bindplane-supervisor_*_windows_amd64.zip` | Windows amd64 |
| `bindplane-supervisor_*_linux_amd64.deb` | Debian/Ubuntu amd64 |
| `bindplane-supervisor_*_linux_arm64.deb` | Debian/Ubuntu arm64 |
| `bindplane-supervisor_*_linux_amd64.rpm` | RHEL/Fedora amd64 |
| `bindplane-supervisor_*_linux_arm64.rpm` | RHEL/Fedora arm64 |
| `bindplane-supervisor_*_windows_amd64.msi` | Windows amd64 |
| `install_unix.sh` | Linux install script |
| `install_darwin.sh` | macOS install script |
| `install_windows.ps1` | Windows install script |
| `bindplane-supervisor-v*-SHA256SUMS` | SHA256 checksums |

### Changelog

The changelog is auto-generated from conventional commit messages:

- `feat:` — New Features
- `fix:` — Bug Fixes
- `deps:` — Dependencies
