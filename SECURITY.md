# Security

OPKG Rewind changes package-manager state on embedded devices. Treat every release as recovery-sensitive software.

## Before using it

- Keep an independent backup of `/opt` and important configuration.
- Run `rewind plan ...` before a package mutation.
- Avoid `--allow-core` unless you have console/recovery access.
- The first public release is intentionally marked pre-release until it has been exercised on real Entware targets.

## Reporting a problem

Open a GitHub issue with the Rewind version, Entware architecture, `opkg --version`, command used, transaction ID, and sanitized output of `rewind status` / `rewind doctor --deep`. Do not post secrets or private configuration.
