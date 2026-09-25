# Changelog

## 0.1.3-1

Drift-baseline correctness after out-of-order manual rollback.

- choose the package-DB baseline from the most recent successful commit/rollback event
- stop assuming the numerically newest transaction is always the latest system state
- add a regression test matching the real-device sequence: newer remove rollback followed by rollback of an older install transaction

## 0.1.2-1

Transaction bookkeeping hardening from repeated real-device testing.

- prevent snapshot-retention iteration from overwriting the active transaction ID
- report the correct committed transaction ID after pruning
- add a regression test that reaches three transactions and verifies the commit banner
- make CI discover the built IPK dynamically instead of hard-coding a release filename

## 0.1.1-1

Rollback hardening from the first real Keenetic/Entware device test.

- preserve post-install package file manifests inside the transaction
- remove transaction-introduced packages through opkg in reverse plan order
- follow package removal with manifest-based orphan cleanup
- add regression coverage where package removal deliberately leaves its payload behind
- keep package DB rollback and drift protection unchanged

## 0.1.0-1

Initial pre-release.

- simulation-first install/upgrade/remove wrapper
- bounded package-owned-file snapshots
- automatic rollback after failed transactions or health checks
- manual rollback with package-database divergence protection
- interrupted transaction recovery
- package/file verification and deep doctor checks
- package-set lockfile and drift detection
- core-package guardrails
- no resident daemon and no additional Entware runtime dependency
