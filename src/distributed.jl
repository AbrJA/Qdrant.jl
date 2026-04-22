# ============================================================================
# Distributed API — HTTP transport
# ============================================================================

"""
    cluster_status(conn) -> QdrantResponse{Dict{String,Any}}

Get cluster status information.
"""
function cluster_status(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/cluster")
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end

"""
    cluster_telemetry(conn) -> QdrantResponse{Dict{String,Any}}

Get cluster-wide telemetry (peers, collections, shard transfers).
"""
function cluster_telemetry(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/cluster/telemetry")
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end

"""
    recover_current_peer(conn) -> QdrantResponse{Bool}

Attempt to recover the current peer.
"""
function recover_current_peer(conn::QdrantConnection{HTTPTransport}=get_client())
    parse_bool(http_request(HTTP.post, conn, "/cluster/recover"))
end

"""
    remove_peer(conn, peer_id; force=false) -> QdrantResponse{Bool}

Remove a peer from the cluster. Fails if peer still has shards.
"""
function remove_peer(conn::QdrantConnection{HTTPTransport}, peer_id::Integer; force::Bool=false)
    kw = force ? (; query=Dict("force" => "true")) : (;)
    parse_bool(http_request(HTTP.delete, conn, "/cluster/peer/$peer_id"; kw...))
end

"""
    collection_cluster_info(conn, collection) -> QdrantResponse{Dict{String,Any}}

Get cluster information for a collection.
"""
function collection_cluster_info(conn::QdrantConnection{HTTPTransport}, name::AbstractString)
    resp = http_request(HTTP.get, conn, "/collections/$name/cluster")
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end
collection_cluster_info(name::AbstractString) = collection_cluster_info(get_client(), name)

"""
    update_collection_cluster(conn, collection, operations) -> QdrantResponse{Bool}

Update collection cluster configuration (move/replicate shards).
"""
function update_collection_cluster(conn::QdrantConnection{HTTPTransport},
                                   name::AbstractString, body::AbstractDict)
    parse_bool(http_request(HTTP.post, conn, "/collections/$name/cluster", body))
end
update_collection_cluster(name::AbstractString, body::AbstractDict) =
    update_collection_cluster(get_client(), name, body)

# ── Shard Keys ───────────────────────────────────────────────────────────

"""
    list_shard_keys(conn, collection) -> QdrantResponse{Dict{String,Any}}

List shard keys for a collection.
"""
function list_shard_keys(conn::QdrantConnection{HTTPTransport}, name::AbstractString)
    resp = http_request(HTTP.get, conn, "/collections/$name/shards")
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end
list_shard_keys(name::AbstractString) = list_shard_keys(get_client(), name)

"""
    create_shard_key(conn, collection, request) -> QdrantResponse{Bool}

Create a shard key for a collection.
"""
function create_shard_key(conn::QdrantConnection{HTTPTransport},
                          name::AbstractString, body::AbstractDict)
    parse_bool(http_request(HTTP.put, conn, "/collections/$name/shards", body))
end
create_shard_key(name::AbstractString, body::AbstractDict) =
    create_shard_key(get_client(), name, body)

"""
    delete_shard_key(conn, collection, request) -> QdrantResponse{Bool}

Delete a shard key from a collection.
"""
function delete_shard_key(conn::QdrantConnection{HTTPTransport},
                          name::AbstractString, body::AbstractDict)
    parse_bool(http_request(HTTP.post, conn, "/collections/$name/shards/delete", body))
end
delete_shard_key(name::AbstractString, body::AbstractDict) =
    delete_shard_key(get_client(), name, body)

# ── Shard Snapshots ──────────────────────────────────────────────────────

"""
    create_shard_snapshot(conn, collection, shard_id) -> QdrantResponse{SnapshotInfo}

Create a snapshot for a specific shard.
"""
function create_shard_snapshot(conn::QdrantConnection{HTTPTransport},
                               name::AbstractString, shard_id::Integer)
    parse_snapshot(http_request(HTTP.post, conn, "/collections/$name/shards/$shard_id/snapshots"))
end

"""
    list_shard_snapshots(conn, collection, shard_id) -> QdrantResponse{Vector{SnapshotInfo}}

List snapshots for a specific shard.
"""
function list_shard_snapshots(conn::QdrantConnection{HTTPTransport},
                              name::AbstractString, shard_id::Integer)
    parse_snapshot_list(http_request(HTTP.get, conn, "/collections/$name/shards/$shard_id/snapshots"))
end

"""
    delete_shard_snapshot(conn, collection, shard_id, snapshot_name) -> QdrantResponse{Bool}

Delete a snapshot for a specific shard.
"""
function delete_shard_snapshot(conn::QdrantConnection{HTTPTransport},
                               name::AbstractString, shard_id::Integer,
                               snapshot_name::AbstractString)
    parse_bool(http_request(HTTP.delete, conn,
        "/collections/$name/shards/$shard_id/snapshots/$snapshot_name"))
end
