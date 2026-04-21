# ============================================================================
# Snapshots API
# ============================================================================

"""
    create_snapshot(client, collection)

Create a snapshot of a collection.
"""
function create_snapshot(c::QdrantConnection, collection::AbstractString)
    execute(HTTP.post, c, "/collections/$collection/snapshots")
end
create_snapshot(collection::AbstractString) = create_snapshot(get_client(), collection)

"""
    list_snapshots(client, collection)

List all snapshots for a collection.
"""
function list_snapshots(c::QdrantConnection, collection::AbstractString)
    result = execute(HTTP.get, c, "/collections/$collection/snapshots")
    result isa AbstractVector ? result : get(result, "snapshots", Any[])
end
list_snapshots(collection::AbstractString) = list_snapshots(get_client(), collection)

"""
    delete_snapshot(client, collection, snapshot_name)

Delete a snapshot.
"""
function delete_snapshot(c::QdrantConnection, collection::AbstractString, name::AbstractString)
    execute(HTTP.delete, c, "/collections/$collection/snapshots/$name")
end
delete_snapshot(collection::AbstractString, name::AbstractString) =
    delete_snapshot(get_client(), collection, name)
