# DWIIS — Developer Workstation Platform

[![Latest release](https://img.shields.io/github/v/release/dedusoft/dwiis-dist?label=release&sort=semver)](https://github.com/dedusoft/dwiis-dist/releases/latest)
[![Website](https://img.shields.io/website?url=https%3A%2F%2Fdwiis.dedusoft.com&label=dwiis.dedusoft.com)](https://dwiis.dedusoft.com)
[![Deploy](https://github.com/dedusoft/dwiis-dist/actions/workflows/pages.yml/badge.svg)](https://github.com/dedusoft/dwiis-dist/actions/workflows/pages.yml)

DWIIS provisions consistent, secure Ubuntu LTS developer workstations in one
command. This repository is the **public distribution channel** for DWIIS:
it hosts [dwiis.dedusoft.com](https://dwiis.dedusoft.com) and the versioned
release downloads.

## Install

```bash
curl -fsSL https://dwiis.dedusoft.com/install.sh | bash
dwiis install --profile backend
```

Verified install (recommended):

```bash
curl -fsSL https://dwiis.dedusoft.com/install.sh -o install.sh
curl -fsSL https://dwiis.dedusoft.com/install.sh.sha256 -o install.sh.sha256
sha256sum -c install.sh.sha256 && bash install.sh
```

| Profile    | Use case                               |
| ---------- | -------------------------------------- |
| `minimal`  | Base CLI tools and shell only          |
| `frontend` | Node, nvm, Docker, VS Code, Chrome     |
| `backend`  | Python, PHP, Docker databases, DBeaver |
| `devops`   | Docker, AWS CLI, kubectl, Helm, Newman |
| `full`     | All company-standard tools             |

Supported systems: Ubuntu **22.04**, **24.04** and **26.04** LTS.

## Update

```bash
dwiis self-update
dwiis install --profile <your-profile>
```

## Downloads

Every [release](https://github.com/dedusoft/dwiis-dist/releases) ships:

| Asset | Description |
| --- | --- |
| `dwiis-<version>.tar.gz` | Platform archive for that version |
| `dwiis-latest.tar.gz` | Same archive under a stable name |
| `*.sha256` | SHA-256 checksum for each file |
| `install.sh` | Bootstrap installer for that version |
| `SHA256SUMS` | All checksums in one file |
| `VERSION` | Version number |

Stable download links always point at the latest release:

```text
https://github.com/dedusoft/dwiis-dist/releases/latest/download/dwiis-latest.tar.gz
https://github.com/dedusoft/dwiis-dist/releases/latest/download/SHA256SUMS
```

Verify a download:

```bash
curl -fsSLO https://github.com/dedusoft/dwiis-dist/releases/latest/download/dwiis-latest.tar.gz
curl -fsSLO https://github.com/dedusoft/dwiis-dist/releases/latest/download/dwiis-latest.tar.gz.sha256
sha256sum -c dwiis-latest.tar.gz.sha256
```

## About this repository

- `site/` is the website served on GitHub Pages. It is generated automatically
  by the DWIIS release pipeline — please don't edit it by hand.
- Releases are created by the same pipeline; tags here match DWIIS versions.
- DWIIS source code is developed privately by Dedusoft. This repository
  contains release builds only.

---

© Dedusoft. DWIIS is proprietary software.
