# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Docker images for ownCloud PHP CI pipelines, published to Docker Hub as `owncloudci/php:<version>`. Versions: 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5. Each is independently built and published.

## Building locally

```bash
# Build a specific version (defaults to v7.4)
BUILD_VERSION=v8.4 make build

# Build multiarch with Docker Buildx (no secrets needed for PHP 8.x)
docker buildx build --platform linux/amd64,linux/arm64 \
  -f v8.4/Dockerfile.multiarch v8.4/

# PHP 7.4 requires Freexian mirror secrets (EOL PHP, needs paid mirror)
docker buildx build --platform linux/amd64 \
  --secret id=mirror-auth,src=./mirror-auth \
  --secret id=mirror-url,src=./mirror-url \
  -f v7.4/Dockerfile.multiarch v7.4/
```

## Linting

The CI lint pipeline runs three checks you can replicate locally:

```bash
# Starlark formatter (checks .drone.star)
buildifier -d -diff_command='diff -u' .drone.star

# EditorConfig format check
docker run --rm -v $(pwd):/app mstruebing/editorconfig-checker

# Shellcheck on overlay scripts (per version)
grep -ErlI '^#!(.*/|.*env +)(sh|bash|ksh)' v8.4/overlay/ | xargs -r shellcheck
```

## Architecture

Each version directory (`v{X.Y}/`) contains:
- `Dockerfile.multiarch` — the image build definition
- `overlay/` — files copied verbatim onto the container root filesystem (`COPY overlay /`). Contains Apache vhost config, PHP ini overrides (opcache, oci8, krb5), SSL config, and a custom `apachectl` wrapper.

**PHP source differences by version:**
- `v7.4`: Uses Freexian's commercial EOL support mirror (requires `mirror-auth` and `mirror-url` secrets at build time). The auth file is explicitly deleted at the end of the build so it cannot leak into the image.
- `v8.0–v8.3`: Uses ondrej/php PPA on Ubuntu 22.04.
- `v8.4`, `v8.5`: Also uses ondrej/php PPA, but builds curl from source (to get gssapi, libssh, nghttp2, ldaps support not present in the distro package).

**Architecture-conditional installs:** Oracle Instant Client (oci8) is only installed on `linux/amd64`. The oci8 PECL extension is guarded by `if [ "$TARGETPLATFORM" = "linux/amd64" ]`.

**PHP 7.4 note:** The overlay PHP ini paths are `etc/php/7.4/...` and include `krb5.ini` (php-krb5 PECL extension), which is absent in 8.x images.

## CI pipeline

Two CI systems coexist:
- **GitHub Actions** (`.github/workflows/main.yml`) — current, uses reusable workflows from `owncloud-docker/ubuntu`. Currently only builds 8.3, 8.4, 8.5 (older versions are commented out in the matrix).
- **Drone CI** (`.drone.star`) — legacy Starlark pipeline; builds all versions, includes Trivy security scanning, pre-publish to internal registry, and Rocket.Chat notifications.

**Dependency updates:** Renovate (`.renovaterc.json`) manages Docker base image digests and the `RETRY_VERSION` env var. GitHub Dependabot manages GitHub Actions versions.

## Adding a new PHP version

1. Copy an existing version directory (e.g., `cp -r v8.4 v8.6`).
2. Update all `php8.4` → `php8.6` references in `Dockerfile.multiarch` and the overlay ini paths.
3. Add the version to the matrix in `.github/workflows/main.yml` and to the `versions` list in `.drone.star`.
4. Update the overlay `etc/php/` path from `8.3` to the correct version (note: v8.4's overlay uses `8.3` paths — verify the actual PHP ini path matches the installed version).
