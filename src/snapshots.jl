# ============================================================================
# Snapshots API — HTTP transport
# ============================================================================

"""
    create_snapshot(conn, collection) -> QdrantResponse{SnapshotInfo}
"""
function create_snapshot(conn::QdrantConnection{HTTPTransport}, collection::AbstractString)
    parse_snapshot(http_request(HTTP.post, conn, "/collections/$collection/snapshots"))
end
create_snapshot(collection::AbstractString) = create_snapshot(get_client(), collection)

"""
    list_snapshots(conn, collection) -> QdrantResponse{Vector{SnapshotInfo}}
"""
function list_snapshots(conn::QdrantConnection{HTTPTransport}, collection::AbstractString)
    parse_snapshot_list(http_request(HTTP.get, conn, "/collections/$collection/snapshots"))
end
list_snapshots(collection::AbstractString) = list_snapshots(get_client(), collection)

"""
    delete_snapshot(conn, collection, snapshot_name) -> QdrantResponse{Bool}
"""
function delete_snapshot(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                         name::AbstractString)
    parse_bool(http_request(HTTP.delete, conn, "/collections/$collection/snapshots/$name"))
end
delete_snapshot(collection::AbstractString, name::AbstractString) =
    delete_snapshot(get_client(), collection, name)

# ── Full Storage Snapshots ───────────────────────────────────────────────

"""
    create_full_snapshot(conn) -> QdrantResponse{SnapshotInfo}
"""
function create_full_snapshot(conn::QdrantConnection{HTTPTransport}=get_client())
    parse_snapshot(http_request(HTTP.post, conn, "/snapshots"))
end

"""
    list_full_snapshots(conn) -> QdrantResponse{Vector{SnapshotInfo}}
"""
function list_full_snapshots(conn::QdrantConnection{HTTPTransport}=get_client())
    parse_snapshot_list(http_request(HTTP.get, conn, "/snapshots"))
end

"""
    delete_full_snapshot(conn, snapshot_name) -> QdrantResponse{Bool}
"""
function delete_full_snapshot(conn::QdrantConnection{HTTPTransport}, name::AbstractString)
    parse_bool(http_request(HTTP.delete, conn, "/snapshots/$name"))
end
delete_full_snapshot(name::AbstractString) = delete_full_snapshot(get_client(), name)

# ── Snapshot Recovery ────────────────────────────────────────────────────

"""
    recover_from_snapshot(conn, collection; location, priority) -> QdrantResponse{Bool}

Recover a collection from a snapshot URL or local path.

# Examples
```julia
recover_from_snapshot(conn, "demo"; location="http://host/snapshot.tar")
recover_from_snapshot(conn, "demo"; location="file:///data/snapshot.tar")
```
"""
function recover_from_snapshot(conn::QdrantConnection{HTTPTransport},
                               collection::AbstractString;
                               location::AbstractString,
                               priority::Optional{String}=nothing)
    body = Dict{String,Any}("location" => location)
    priority !== nothing && (body["priority"] = priority)
    parse_bool(http_request(HTTP.put, conn, "/collections/$collection/snapshots/recover", body))
end
recover_from_snapshot(collection::AbstractString; kw...) =
    recover_from_snapshot(get_client(), collection; kw...)
