# ============================================================================
# Search / Recommend / Query API
# ============================================================================

# All search-family functions share the pattern:
#   1. Primary method: (client, collection, request::AbstractRequest)
#   2. Default-client method: (collection, request)
#   3. Keyword method: (client, collection; kwargs...) for simple cases

_search_path(coll::AbstractString) = "/collections/$coll/points"

# ── Search ───────────────────────────────────────────────────────────────

"""
    search_points(client, collection, request::SearchRequest)
    search_points(client, collection; vector, limit, kwargs...)

Search for nearest neighbors.

# Examples
```julia
search_points(client, "my_col", SearchRequest(vector=Float32[1,0,0,0], limit=5))
search_points(client, "my_col"; vector=Float32[1,0,0,0], limit=5, with_payload=true)
```
"""
function search_points(c::Client, coll::AbstractString, req::SearchRequest)
    _rp(HTTP.post, c, _search_path(coll) * "/search", todict(req))
end
search_points(coll::AbstractString, req::SearchRequest) = search_points(get_client(), coll, req)
search_points(c::Client, coll::AbstractString; kwargs...) =
    search_points(c, coll, SearchRequest(; kwargs...))
search_points(coll::AbstractString; kwargs...) = search_points(get_client(), coll; kwargs...)

"""
    search_batch(client, collection, requests::AbstractVector{SearchRequest})

Execute multiple searches in one call.
"""
function search_batch(c::Client, coll::AbstractString, reqs::AbstractVector{SearchRequest})
    body = Dict{String,Any}("searches" => [todict(r) for r in reqs])
    _rp(HTTP.post, c, _search_path(coll) * "/search/batch", body)
end
search_batch(coll::AbstractString, reqs::AbstractVector{SearchRequest}) =
    search_batch(get_client(), coll, reqs)

"""
    search_groups(client, collection, request::Dict; group_size=1)

Search with result grouping.
"""
function search_groups(c::Client, coll::AbstractString, req::AbstractDict; group_size::Int=1)
    body = merge(Dict{String,Any}(req), Dict{String,Any}("group_size" => group_size))
    _rp(HTTP.post, c, _search_path(coll) * "/search/groups", body)
end
search_groups(coll::AbstractString, req::AbstractDict; kw...) =
    search_groups(get_client(), coll, req; kw...)

# ── Recommend ────────────────────────────────────────────────────────────

"""
    recommend_points(client, collection, request::RecommendRequest)
    recommend_points(client, collection; positive, limit, kwargs...)

Get recommendations from positive/negative examples.
"""
function recommend_points(c::Client, coll::AbstractString, req::RecommendRequest)
    _rp(HTTP.post, c, _search_path(coll) * "/recommend", todict(req))
end
recommend_points(coll::AbstractString, req::RecommendRequest) =
    recommend_points(get_client(), coll, req)
recommend_points(c::Client, coll::AbstractString; kwargs...) =
    recommend_points(c, coll, RecommendRequest(; kwargs...))
recommend_points(coll::AbstractString; kwargs...) =
    recommend_points(get_client(), coll; kwargs...)

"""
    recommend_batch(client, collection, requests)

Execute multiple recommendations in one call.
"""
function recommend_batch(c::Client, coll::AbstractString, reqs::AbstractVector{RecommendRequest})
    body = Dict{String,Any}("searches" => [todict(r) for r in reqs])
    _rp(HTTP.post, c, _search_path(coll) * "/recommend/batch", body)
end
recommend_batch(coll::AbstractString, reqs::AbstractVector{RecommendRequest}) =
    recommend_batch(get_client(), coll, reqs)

"""
    recommend_groups(client, collection, request; group_size=1)

Recommendations with grouping.
"""
function recommend_groups(c::Client, coll::AbstractString, req::AbstractDict; group_size::Int=1)
    body = merge(Dict{String,Any}(req), Dict{String,Any}("group_size" => group_size))
    _rp(HTTP.post, c, _search_path(coll) * "/recommend/groups", body)
end
recommend_groups(coll::AbstractString, req::AbstractDict; kw...) =
    recommend_groups(get_client(), coll, req; kw...)

# ── Query ────────────────────────────────────────────────────────────────

"""
    query_points(client, collection, request::QueryRequest)
    query_points(client, collection; query, limit, kwargs...)

Advanced query interface.
"""
function query_points(c::Client, coll::AbstractString, req::QueryRequest)
    _rp(HTTP.post, c, _search_path(coll) * "/query", todict(req))
end
query_points(coll::AbstractString, req::QueryRequest) = query_points(get_client(), coll, req)
query_points(c::Client, coll::AbstractString; kwargs...) =
    query_points(c, coll, QueryRequest(; kwargs...))
query_points(coll::AbstractString; kwargs...) = query_points(get_client(), coll; kwargs...)

"""
    query_batch(client, collection, requests)

Execute multiple queries in one call.
"""
function query_batch(c::Client, coll::AbstractString, reqs::AbstractVector{QueryRequest})
    body = Dict{String,Any}("searches" => [todict(r) for r in reqs])
    _rp(HTTP.post, c, _search_path(coll) * "/query/batch", body)
end
query_batch(coll::AbstractString, reqs::AbstractVector{QueryRequest}) =
    query_batch(get_client(), coll, reqs)

"""
    query_groups(client, collection, request; group_size=1)

Query with grouping.
"""
function query_groups(c::Client, coll::AbstractString, req::AbstractDict; group_size::Int=1)
    body = merge(Dict{String,Any}(req), Dict{String,Any}("group_size" => group_size))
    _rp(HTTP.post, c, _search_path(coll) * "/query/groups", body)
end
query_groups(coll::AbstractString, req::AbstractDict; kw...) =
    query_groups(get_client(), coll, req; kw...)
