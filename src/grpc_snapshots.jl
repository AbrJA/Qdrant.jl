# ============================================================================
# gRPC Snapshots API — dispatch on GRPCTransport
# ============================================================================

function create_snapshot(c::QdrantConnection, collection::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.CreateSnapshotRequest(collection)
    resp = grpc_request(transport, Snapshots_Create_Client, req)
    result = Dict{String,Any}("time" => resp.time)
    if resp.snapshot_description !== nothing
        sd = resp.snapshot_description
        result["name"] = sd.name
        result["size"] = Int(sd.size)
        !isempty(sd.checksum) && (result["checksum"] = sd.checksum)
    end
    result
end

function list_snapshots(c::QdrantConnection, collection::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.ListSnapshotsRequest(collection)
    resp = grpc_request(transport, Snapshots_List_Client, req)
    [Dict{String,Any}(
        "name" => sd.name,
        "size" => Int(sd.size),
        "checksum" => sd.checksum,
    ) for sd in resp.snapshot_descriptions]
end

function delete_snapshot(c::QdrantConnection, collection::AbstractString,
                         name::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.DeleteSnapshotRequest(collection, name)
    resp = grpc_request(transport, Snapshots_Delete_Client, req)
    true
end
