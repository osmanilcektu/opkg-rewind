# Design constraints

## Non-negotiables

- No resident daemon.
- No network activity except the `opkg` command the user explicitly invokes.
- No additional runtime package dependencies.
- No replacement of `opkg`; Rewind is a safety wrapper.
- No write outside `/opt` for package snapshots/state.
- No mutation before a successful `opkg --noaction` plan and rollback snapshot.
- Never silently allow high-risk core package changes.
- Never roll an old committed snapshot back over a package DB that has changed since that transaction unless the operator explicitly forces it.

## Transaction states

`preparing -> running -> committed`

Failure paths may become `snapshot_failed`, `failed`, `health_failed`, `rolling_back`, `rolled_back`, or `rollback_failed`.

## Why shell

A native compiled binary would reduce process spawning, but shipping one portable binary across every Entware architecture is impossible without multiple builds. POSIX shell keeps the package `Architecture: all`, adds no runtime, and makes the same package usable on MIPS, ARM, AArch64, x86, and x86_64 devices. Rewind is not a continuously running workload, so transient BusyBox process spawning is preferable to a persistent runtime dependency.

## Snapshot strategy

For every package present in the `opkg --noaction` plan, Rewind captures:

- the global opkg status database;
- `/opt/lib/opkg/info/<package>.*` metadata;
- package-owned files from `<package>.list` that currently exist;
- pre-transaction installed/version state.

Directories are not recursively copied because a package list may contain a shared directory such as `/opt/lib`. Recursively copying that directory would massively increase writes and could copy unrelated packages. Only owned leaf files/symlinks are snapshotted.

## Core package protection

The first release guards known Entware foundations such as `opkg`, `entware-opt`, `busybox`, `libc`, `libgcc`, `libpthread`, `librt`, and `libstdcpp`. The guard applies to upgrade, downgrade, and removal plans, including dependency-driven plan entries.

## Future work

Future releases can add optional repository package caching for stronger historical-version restore, signature/history reporting, per-package policy rules, and platform-specific filesystem snapshot adapters. Those features must remain optional and must not turn the core into a daemon.
