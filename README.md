# OPKG Rewind

[![CI](https://github.com/osmanilcektu/opkg-rewind/actions/workflows/ci.yml/badge.svg)](https://github.com/osmanilcektu/opkg-rewind/actions/workflows/ci.yml)


OPKG Rewind is a zero-extra-package safety layer for Entware's existing `opkg` package manager. It is designed for embedded routers and NAS devices where RAM, flash/USB writes, and recovery options are limited.

It is intentionally **not** a daemon, web UI, scheduler, telemetry agent, or alternative package manager. It wakes only when you run it.

## Runtime requirements

No additional Entware packages are required. Runtime assumptions are limited to:

- POSIX `/bin/sh`
- the device's normal BusyBox/POSIX utility set (`awk`, `grep`, `cp`, `mv`, `rm`, `mkdir`, `df`, `date`, `sort`, `tail`, `cmp`, etc.)
- the already-installed Entware `opkg`
- a writable `/opt`

There is no Python, Node.js, Go runtime, jq, curl, SQLite, systemd, or background service dependency.

## Purpose

Normal `opkg` can simulate an operation with `--noaction`, but it does not provide a general transaction history and package-file rollback workflow. Rewind wraps mutating operations with:

1. simulation / dependency-plan capture;
2. core-package guardrails;
3. free-space checks;
4. a snapshot of affected package-owned files and opkg metadata;
5. the real opkg transaction;
6. post-transaction package/file health checks;
7. automatic rollback on failure;
8. bounded snapshot retention.

## Commands

```sh
rewind status
rewind doctor
rewind doctor --deep
rewind plan install nano
rewind install nano
rewind upgrade curl
rewind remove htop
rewind history
rewind rollback
rewind rollback 000042
rewind recover
rewind verify
rewind verify curl
rewind lock /opt/etc/my-router.opkg.lock
rewind lock-check /opt/etc/my-router.opkg.lock
rewind update
```

Core package upgrades/removals are blocked by default. They require an explicit:

```sh
rewind upgrade --allow-core opkg
```

That switch is deliberately noisy because changing the package manager or C runtime on an embedded system has a larger recovery blast radius.

## Storage model

State is stored under:

```text
/opt/var/lib/opkg-rewind/
```

Default policy retains only the three newest completed rollback snapshots and caps an estimated snapshot at 32 MiB. No process remains resident in RAM.

## Rollback boundary

Rewind restores package-owned files and the opkg package database/metadata captured before a transaction. For packages introduced by a transaction, rollback first asks opkg to remove them in reverse dependency-plan order, then applies a preserved post-install file manifest to clean any package-owned payload that remains.

It cannot make arbitrary package maintainer scripts fully transactional. A `postinst` script can, in principle, modify files outside the package's declared file list or change external state. Rewind therefore does not claim filesystem-level atomicity. On platforms with native filesystem snapshots, those remain stronger than package-file rollback.

## Package DB divergence protection

A manually requested rollback of a committed transaction is refused if the current opkg status database differs from the post-transaction fingerprint. This prevents an old snapshot from silently overwriting later package changes. `--force` exists for deliberate recovery only.

`rewind status` and `rewind doctor` also compare the current package database with the latest completed Rewind baseline. If someone runs raw `opkg install/remove/upgrade` outside Rewind afterwards, that out-of-band package-state drift is reported instead of silently assuming the snapshot chain is current.

## Development/test override

The implementation supports test-only path overrides:

```sh
REWIND_ROOT=/tmp/test/opt \
REWIND_OPKG=/tmp/test/opt/bin/opkg \
./src/rewind doctor
```

These are also used by the included mock test suite.

## Install

The current pre-release package is committed under `dist/` so it can be downloaded directly from the repository. Future tagged versions are also built and published automatically by GitHub Actions.

Download `dist/opkg-rewind_0.1.1-1_all.ipk` to your computer, copy it to the router, then install it with the existing Entware `opkg`:

```sh
opkg install /tmp/opkg-rewind_0.1.1-1_all.ipk
rewind version
rewind status
rewind doctor --deep
```

The package itself does not fetch anything and does not install additional dependencies.

## Release maturity

`0.1.x` is a pre-release line. The transaction engine is covered by the included mock-opkg regression suite and BusyBox `ash` syntax validation, but real-device testing across Entware targets is still required before claiming broad production compatibility.
