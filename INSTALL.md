# Installing bindplane-supervisor via APT

## Prerequisites

- A Debian-based Linux distribution (Debian, Ubuntu, etc.)
- `curl` and root/sudo access

> **Note:** GPG signing is not currently enabled for this repository. The
> instructions below use `[trusted=yes]` to allow APT to fetch packages without
> signature verification. Once GPG signing is enabled this will be replaced with
> proper key verification.

## Add the APT Repository

```bash
# Add the repository source list.
# Replace OWNER with the GitHub org or user (e.g. observIQ).
echo "deb [trusted=yes] https://OWNER.github.io/bindplane-supervisor/dists/stable/ stable main" \
  | sudo tee /etc/apt/sources.list.d/bindplane-supervisor.list > /dev/null
```

<!-- GPG_SIGNING: When GPG signing is enabled, replace the block above with:
```bash
# Download the repository signing key.
curl -fsSL https://OWNER.github.io/bindplane-supervisor/signing-key.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/bindplane-supervisor.gpg

# Add the repository with keyring-based verification.
echo "deb [signed-by=/usr/share/keyrings/bindplane-supervisor.gpg] https://OWNER.github.io/bindplane-supervisor/dists/stable/ stable main" \
  | sudo tee /etc/apt/sources.list.d/bindplane-supervisor.list > /dev/null
```
-->

## Install

```bash
sudo apt-get update
sudo apt-get install bindplane-supervisor
```

## Update

```bash
sudo apt-get update
sudo apt-get upgrade bindplane-supervisor
```

## Install a Specific Version

```bash
# List available versions.
apt-cache madison bindplane-supervisor

# Install a specific version.
sudo apt-get install bindplane-supervisor=<version>
```

## Uninstall

```bash
sudo apt-get remove bindplane-supervisor

# To also remove configuration files:
sudo apt-get purge bindplane-supervisor
```
