# ============================================================================
# Discovery API
# ============================================================================

"""
    discover_points(client, collection, request::DiscoverRequest)

Discover points similar to a target with optional context.
"""
function discover_points(c::Client, coll::AbstractString, req::DiscoverRequest)
    _rp(HTTP.post, c, "/collections/$coll/points/discover", todict(req))
end
discover_points(coll::AbstractString, req::DiscoverRequest) =
    discover_points(get_client(), coll, req)

"""
    discover_batch(client, collection, requests)

Execute multiple discovery requests in one call.
"""
function discover_batch(c::Client, coll::AbstractString, reqs::AbstractVector{DiscoverRequest})
    body = Dict{String,Any}("searches" => [todict(r) for r in reqs])
    _rp(HTTP.post, c, "/collections/$coll/points/discover/batch", body)
end
discover_batch(coll::AbstractString, reqs::AbstractVector{DiscoverRequest}) =
    discover_batch(get_client(), coll, reqs)
