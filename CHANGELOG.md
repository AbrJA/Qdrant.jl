# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [1.0.0] - 2026-04-22

### Added
- Dual transport architecture with HTTP and gRPC dispatch.
- OpenAPI coverage expanded to 58/65 non-deprecated operations.
- New service endpoints: health probes and issues APIs.
- New distributed endpoints: cluster telemetry/recovery, shard keys, shard snapshots, and cluster update APIs.
- Snapshot URL recovery endpoint.

### Changed
- Health probe and metrics text endpoints now return plain text payloads with empty status field.
- Integration tests expanded for newly added endpoints.

### Notes
- Remaining 7 operations are intentionally out of scope for v1.0 due to binary streaming or multipart upload requirements.
