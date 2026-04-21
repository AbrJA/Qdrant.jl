# ============================================================================
# Snapshots API
# ============================================================================

"""
    create_snapshot(client, collection)

Create a snapshot of a collection.
"""
function create_snapshot(c::Client, coll::AbstractString)
    _rp(HTTP.post, c, "/collections/$coll/snapshots")
end
create_snapshot(coll::AbstractString) = create_snapshot(get_client(), coll)

"""
    list_snapshots(client, collection)

List all snapshots for a collection.
"""
function list_snapshots(c::Client, coll::AbstractString)
    result = _rp(HTTP.get, c, "/collections/$coll/snapshots")
    result isa AbstractVector ? result : get(result, :snapshots, Any[])
end
list_snapshots(coll::AbstractString) = list_snapshots(get_client(), coll)

"""
    delete_snapshot(client, collection, snapshot_name)

Delete a snapshot.
"""
function delete_snapshot(c::Client, coll::AbstractString, name::AbstractString)
    _rp(HTTP.delete, c, "/collections/$coll/snapshots/$name")
end
delete_snapshot(coll::AbstractString, name::AbstractString) =
    delete_snapshot(get_client(), coll, name)
