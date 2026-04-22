# OpenAPI Coverage Matrix (Non-Deprecated Operations)

| operationId | method | path | implemented | tested |
|---|---|---|---|---|
| batch_update | POST | `/collections/{collection_name}/points/batch` | yes | yes |
| clear_issues | DELETE | `/issues` | yes | yes |
| clear_payload | POST | `/collections/{collection_name}/points/payload/clear` | yes | yes |
| cluster_status | GET | `/cluster` | yes | yes |
| cluster_telemetry | GET | `/cluster/telemetry` | yes | yes |
| collection_cluster_info | GET | `/collections/{collection_name}/cluster` | yes | yes |
| collection_exists | GET | `/collections/{collection_name}/exists` | yes | yes |
| count_points | POST | `/collections/{collection_name}/points/count` | yes | yes |
| create_collection | PUT | `/collections/{collection_name}` | yes | yes |
| create_field_index | PUT | `/collections/{collection_name}/index` | yes | yes |
| create_full_snapshot | POST | `/snapshots` | yes | yes |
| create_shard_key | PUT | `/collections/{collection_name}/shards` | yes | no |
| create_shard_snapshot | POST | `/collections/{collection_name}/shards/{shard_id}/snapshots` | yes | no |
| create_snapshot | POST | `/collections/{collection_name}/snapshots` | yes | yes |
| delete_collection | DELETE | `/collections/{collection_name}` | yes | yes |
| delete_field_index | DELETE | `/collections/{collection_name}/index/{field_name}` | yes | yes |
| delete_full_snapshot | DELETE | `/snapshots/{snapshot_name}` | yes | yes |
| delete_payload | POST | `/collections/{collection_name}/points/payload/delete` | yes | yes |
| delete_points | POST | `/collections/{collection_name}/points/delete` | yes | yes |
| delete_shard_key | POST | `/collections/{collection_name}/shards/delete` | yes | no |
| delete_shard_snapshot | DELETE | `/collections/{collection_name}/shards/{shard_id}/snapshots/{snapshot_name}` | yes | no |
| delete_snapshot | DELETE | `/collections/{collection_name}/snapshots/{snapshot_name}` | yes | yes |
| delete_vectors | POST | `/collections/{collection_name}/points/vectors/delete` | yes | yes |
| facet | POST | `/collections/{collection_name}/facet` | yes | yes |
| get_collection | GET | `/collections/{collection_name}` | yes | yes |
| get_collection_aliases | GET | `/collections/{collection_name}/aliases` | yes | yes |
| get_collections | GET | `/collections` | yes | yes |
| get_collections_aliases | GET | `/aliases` | yes | yes |
| get_full_snapshot | GET | `/snapshots/{snapshot_name}` | no (binary) | — |
| get_issues | GET | `/issues` | yes | yes |
| get_optimizations | GET | `/collections/{collection_name}/optimizations` | yes | yes |
| get_point | GET | `/collections/{collection_name}/points/{id}` | yes | yes |
| get_points | POST | `/collections/{collection_name}/points` | yes | yes |
| get_shard_snapshot | GET | `/collections/{collection_name}/shards/{shard_id}/snapshots/{snapshot_name}` | no (binary) | — |
| get_snapshot | GET | `/collections/{collection_name}/snapshots/{snapshot_name}` | no (binary) | — |
| healthz | GET | `/healthz` | yes | yes |
| list_full_snapshots | GET | `/snapshots` | yes | yes |
| list_shard_keys | GET | `/collections/{collection_name}/shards` | yes | yes |
| list_shard_snapshots | GET | `/collections/{collection_name}/shards/{shard_id}/snapshots` | yes | no |
| list_snapshots | GET | `/collections/{collection_name}/snapshots` | yes | yes |
| livez | GET | `/livez` | yes | yes |
| metrics | GET | `/metrics` | yes | yes |
| overwrite_payload | PUT | `/collections/{collection_name}/points/payload` | yes | yes |
| query_batch_points | POST | `/collections/{collection_name}/points/query/batch` | yes | yes |
| query_points | POST | `/collections/{collection_name}/points/query` | yes | yes |
| query_points_groups | POST | `/collections/{collection_name}/points/query/groups` | yes | yes |
| readyz | GET | `/readyz` | yes | yes |
| recover_current_peer | POST | `/cluster/recover` | yes | yes |
| recover_from_snapshot | PUT | `/collections/{collection_name}/snapshots/recover` | yes | yes |
| recover_from_uploaded_snapshot | POST | `/collections/{collection_name}/snapshots/upload` | no (multipart) | — |
| recover_shard_from_snapshot | PUT | `/collections/{collection_name}/shards/{shard_id}/snapshots/recover` | no (shard-level) | — |
| recover_shard_from_uploaded_snapshot | POST | `/collections/{collection_name}/shards/{shard_id}/snapshots/upload` | no (multipart) | — |
| remove_peer | DELETE | `/cluster/peer/{peer_id}` | yes | no |
| root | GET | `/` | yes | yes |
| scroll_points | POST | `/collections/{collection_name}/points/scroll` | yes | yes |
| search_matrix_offsets | POST | `/collections/{collection_name}/points/search/matrix/offsets` | yes | yes |
| search_matrix_pairs | POST | `/collections/{collection_name}/points/search/matrix/pairs` | yes | yes |
| set_payload | POST | `/collections/{collection_name}/points/payload` | yes | yes |
| stream_shard_snapshot | GET | `/collections/{collection_name}/shards/{shard_id}/snapshot` | no (binary) | — |
| telemetry | GET | `/telemetry` | yes | yes |
| update_aliases | POST | `/collections/aliases` | yes | yes |
| update_collection | PATCH | `/collections/{collection_name}` | yes | yes |
| update_collection_cluster | POST | `/collections/{collection_name}/cluster` | yes | no |
| update_vectors | PUT | `/collections/{collection_name}/points/vectors` | yes | yes |
| upsert_points | PUT | `/collections/{collection_name}/points` | yes | yes |

- Total non-deprecated operations: 65
- Implemented in client: 58
- Not implemented (intentionally): 7
  - `get_snapshot`, `get_full_snapshot`, `get_shard_snapshot`, `stream_shard_snapshot` — binary file downloads requiring streaming I/O
  - `recover_from_uploaded_snapshot`, `recover_shard_from_uploaded_snapshot` — multipart/form-data file uploads
  - `recover_shard_from_snapshot` — shard-level URL recovery, too specialized for v1.0
