# Changelog

All notable changes to LOKI are documented here.

## [1.0.2] - 2026-08-17

### Fixed
- `loki connect` / `loki refresh` no longer fail with `bind() ... Address already in use`
  when nginx has no running master (stale pid). Reload now falls back to killing
  stragglers and retrying `nginx` for up to 10s so listen sockets are free first.

## [1.0.1] - 2025-10-28

- Install script and CLI fixes.

## [1.0.0] - 2025-10-27

- Initial release.
