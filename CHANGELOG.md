# Changelog

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
