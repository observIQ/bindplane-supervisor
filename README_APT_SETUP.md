# APT Repository Setup

This project uses **GitHub Pages** to host APT repository metadata and
**GitHub Releases** to store the actual `.deb` packages. GoReleaser builds
`.deb` files on every tagged release, and a GitHub Actions workflow
(`.github/workflows/apt-repo.yml`) regenerates the APT metadata automatically.

## Architecture

```
GitHub Release (v1.2.3)
  └─ bindplane-supervisor_v1.2.3_linux_amd64.deb
  └─ bindplane-supervisor_v1.2.3_linux_arm64.deb

gh-pages branch (served by GitHub Pages)
  ├─ pool/main/              ← .deb files copied here
  │   ├─ bindplane-supervisor_v1.2.3_linux_amd64.deb
  │   └─ bindplane-supervisor_v1.2.3_linux_arm64.deb
  ├─ dists/stable/
  │   ├─ Release             ← repository-level metadata
  │   ├─ main/
  │   │   ├─ binary-amd64/
  │   │   │   ├─ Packages
  │   │   │   └─ Packages.gz
  │   │   └─ binary-arm64/
  │   │       ├─ Packages
  │   │       └─ Packages.gz
  │   # After GPG signing is enabled:
  │   # ├─ InRelease          ← inline-signed Release
  │   # └─ Release.gpg        ← detached Release signature
  └─ # signing-key.gpg        ← public GPG key for users
```

**How it works:**

1. A developer pushes a tag (`v1.2.3`).
2. The `release.yml` workflow runs GoReleaser, which builds and uploads `.deb`
   files to the GitHub Release.
3. The `apt-repo.yml` workflow triggers on release publication, downloads the
   `.deb` files, generates APT metadata, and pushes to `gh-pages`.
4. GitHub Pages serves the `gh-pages` branch, making the APT repo available at
   `https://<OWNER>.github.io/bindplane-supervisor/`.

## Initial Setup

### 1. Create the gh-pages branch

The `gh-pages` branch must exist before the workflow can push to it. Create it
as an empty orphan branch:

```bash
git checkout --orphan gh-pages
git rm -rf .
echo "APT repository for bindplane-supervisor" > index.html
git add index.html
git commit -m "Initialize gh-pages branch"
git push origin gh-pages
git checkout main
```

### 2. Enable GitHub Pages

1. Go to the repository **Settings > Pages**.
2. Under **Source**, select **Deploy from a branch**.
3. Set the branch to `gh-pages` and the folder to `/ (root)`.
4. Click **Save**.

The repository will be available at
`https://<OWNER>.github.io/bindplane-supervisor/` once the first workflow run
populates it.

### 3. Verify

After the next release (or a manual workflow dispatch), confirm:

```bash
curl -s https://<OWNER>.github.io/bindplane-supervisor/dists/stable/Release
```

You should see the `Release` file contents with `Origin`, `Label`, checksums,
etc.

## Adding GPG Signing

GPG signing lets users verify that the repository metadata has not been
tampered with. The workflow and install instructions already contain
commented-out GPG sections marked with `GPG_SIGNING:`.

### Step 1 — Generate a GPG key (if you don't have one)

```bash
gpg --full-generate-key
# Choose RSA (sign only), 4096 bits, no expiration (or set one).
# Note the key ID from the output.
```

### Step 2 — Add GitHub secrets

Go to **Settings > Secrets and variables > Actions** and add:

| Secret             | Value                                                        |
|--------------------|--------------------------------------------------------------|
| `GPG_PRIVATE_KEY`  | `gpg --armor --export-secret-keys <KEY_ID>`                  |
| `GPG_PASSPHRASE`   | Passphrase for the key                                       |
| `GPG_KEY_ID`       | Key ID or email (e.g. `ABCDEF1234567890` or `you@example.com`) |

### Step 3 — Uncomment GPG sections

In `.github/workflows/apt-repo.yml`, find every block prefixed with
`# GPG_SIGNING:` and uncomment the steps below it:

- **Import GPG key** — imports the private key into the runner's keyring.
- **Sign Release file** — generates `InRelease` and `Release.gpg`.
- **Export public key for users** — writes `signing-key.gpg` for users.

In `INSTALL.md`, swap the `[trusted=yes]` source list entry for the
`[signed-by=...]` entry inside the `<!-- GPG_SIGNING: ... -->` comment block.

### Step 4 — Test

Trigger a manual workflow run and verify:

```bash
# The InRelease file should exist and contain a PGP signature.
curl -s https://<OWNER>.github.io/bindplane-supervisor/dists/stable/InRelease | head -5

# The public key should be downloadable.
curl -fsSL https://<OWNER>.github.io/bindplane-supervisor/signing-key.gpg | gpg --show-keys
```

## Troubleshooting

### `apt-get update` returns 404

- Confirm GitHub Pages is enabled and serving from `gh-pages`.
- Confirm the `gh-pages` branch contains `dists/stable/Release`.
- The sources list URL must **not** include a trailing slash after the hostname
  path.

### `apt-get update` shows "The repository is not signed"

This is expected while GPG signing is disabled. Using `[trusted=yes]` in the
source list suppresses this error. Follow the GPG signing steps above to
resolve it permanently.

### Workflow fails with "no .deb files found"

- Confirm GoReleaser is configured to produce `.deb` packages (check the
  `nfpms` section in `.goreleaser.yaml`).
- Check the GitHub Release assets to verify `.deb` files were uploaded.
- If the release was created as a draft, `.deb` files may not be available
  until the release is published.

### Old package versions not available

Every workflow run copies all `.deb` files to `pool/main/` and regenerates the
index. Older versions remain available as long as their `.deb` files stay in
`pool/main/` on the `gh-pages` branch.

### Workflow needs to be re-run for an existing release

Use the manual workflow dispatch:

1. Go to **Actions > Update APT Repository**.
2. Click **Run workflow**.
3. Enter the release tag (e.g. `v1.2.3`).
