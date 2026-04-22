# ============================================================================
# Discovery API
# ============================================================================

"""
    discover_points(client, collection, request::DiscoverRequest)

Discover points similar to a target with optional context.
"""
function discover_points(c::QdrantConnection, collection::AbstractString, req::DiscoverRequest)
    is_grpc(c) && return discover_points(c, collection, req, Val(:grpc))
    execute(HTTP.post, c, "/collections/$collection/points/discover", req)
end
discover_points(collection::AbstractString, req::DiscoverRequest) =
    discover_points(get_client(), collection, req)

"""
    discover_batch(client, collection, requests)

Execute multiple discovery requests in one call.
"""
function discover_batch(c::QdrantConnection, collection::AbstractString,
                        requests::AbstractVector{DiscoverRequest})
    is_grpc(c) && return discover_batch(c, collection, requests, Val(:grpc))
    body = Dict{String,Any}("searches" => collect(requests))
    execute(HTTP.post, c, "/collections/$collection/points/discover/batch", body)
end
discover_batch(collection::AbstractString, requests::AbstractVector{DiscoverRequest}) =
    discover_batch(get_client(), collection, requests)
