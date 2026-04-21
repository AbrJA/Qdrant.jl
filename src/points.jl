# ============================================================================
# Points API — multiple dispatch on selectors
# ============================================================================

_pts_path(coll::AbstractString) = "/collections/$coll/points"

# ── Selector dispatch ────────────────────────────────────────────────────
# Holy-trait style: the _body for selecting points differs by type.

_selector(ids::AbstractVector{<:PointId}) = Dict{String,Any}("points" => collect(ids))
_selector(f::Filter) = Dict{String,Any}("filter" => todict(f))

# Single-id convenience → wraps into vector
_selector(id::PointId) = _selector([id])

_wait_q(wait::Bool) = Dict("wait" => wait)

# ============================================================================
# CRUD
# ============================================================================

"""
    upsert_points(client, collection, points; wait=true, ordering="weak")

Insert or update points.
"""
function upsert_points(c::Client, coll::AbstractString, points::AbstractVector{<:PointStruct};
                       wait::Bool=true, ordering::AbstractString="weak")
    body = Dict{String,Any}("points" => [todict(p) for p in points], "ordering" => ordering)
    _rp(HTTP.put, c, _pts_path(coll), body; query=_wait_q(wait))
end
upsert_points(coll::AbstractString, pts::AbstractVector{<:PointStruct}; kw...) =
    upsert_points(get_client(), coll, pts; kw...)

"""
    delete_points(client, collection, selector; wait=true)

Delete points by IDs or filter.

# Dispatch
- `selector::AbstractVector{<:PointId}` — delete by ID list
- `selector::PointId` — delete single point
- `selector::Filter` — delete by filter
"""
function delete_points(c::Client, coll::AbstractString, sel::Union{AbstractVector{<:PointId}, PointId, Filter};
                       wait::Bool=true)
    _rp(HTTP.post, c, _pts_path(coll) * "/delete", _selector(sel); query=_wait_q(wait))
end
delete_points(coll::AbstractString, sel; kw...) = delete_points(get_client(), coll, sel; kw...)

"""
    get_points(client, collection, ids; with_vectors=false, with_payload=true)
    get_points(client, collection, id::PointId; ...)

Retrieve points by ID(s).
"""
function get_points(c::Client, coll::AbstractString, ids::AbstractVector{<:PointId};
                    with_vectors::Bool=false, with_payload::Bool=true)
    body = Dict{String,Any}("ids" => collect(ids), "with_vectors" => with_vectors, "with_payload" => with_payload)
    _rp(HTTP.post, c, _pts_path(coll), body)
end
get_points(c::Client, coll::AbstractString, id::PointId; kw...) = get_points(c, coll, [id]; kw...)
get_points(coll::AbstractString, ids; kw...) = get_points(get_client(), coll, ids; kw...)

# ============================================================================
# Payload operations — dispatch on selector type
# ============================================================================

"""
    set_payload(client, collection, payload, selector; wait=true)

Set payload fields on selected points.
"""
function set_payload(c::Client, coll::AbstractString, payload::AbstractDict,
                     sel::Union{AbstractVector{<:PointId}, PointId, Filter}; wait::Bool=true)
    body = merge(Dict{String,Any}("payload" => payload), _selector(sel))
    _rp(HTTP.post, c, _pts_path(coll) * "/payload", body; query=_wait_q(wait))
end
set_payload(coll::AbstractString, payload::AbstractDict, sel; kw...) =
    set_payload(get_client(), coll, payload, sel; kw...)

"""
    delete_payload(client, collection, keys, selector; wait=true)

Delete payload keys from selected points.
"""
function delete_payload(c::Client, coll::AbstractString, keys::AbstractVector{<:AbstractString},
                        sel::Union{AbstractVector{<:PointId}, PointId, Filter}; wait::Bool=true)
    body = merge(Dict{String,Any}("keys" => collect(keys)), _selector(sel))
    _rp(HTTP.post, c, _pts_path(coll) * "/payload/delete", body; query=_wait_q(wait))
end
delete_payload(coll::AbstractString, keys::AbstractVector{<:AbstractString}, sel; kw...) =
    delete_payload(get_client(), coll, keys, sel; kw...)

"""
    clear_payload(client, collection, selector; wait=true)

Remove all payload from selected points.
"""
function clear_payload(c::Client, coll::AbstractString,
                       sel::Union{AbstractVector{<:PointId}, PointId, Filter}; wait::Bool=true)
    _rp(HTTP.post, c, _pts_path(coll) * "/payload/clear", _selector(sel); query=_wait_q(wait))
end
clear_payload(coll::AbstractString, sel; kw...) = clear_payload(get_client(), coll, sel; kw...)

# ============================================================================
# Vector operations
# ============================================================================

"""
    update_vectors(client, collection, points; wait=true)

Update vectors for existing points.
"""
function update_vectors(c::Client, coll::AbstractString, points::AbstractVector{<:PointStruct};
                        wait::Bool=true)
    body = Dict{String,Any}("points" => [todict(p) for p in points])
    _rp(HTTP.put, c, _pts_path(coll) * "/vectors", body; query=_wait_q(wait))
end
update_vectors(coll::AbstractString, pts::AbstractVector{<:PointStruct}; kw...) =
    update_vectors(get_client(), coll, pts; kw...)

"""
    delete_vectors(client, collection, vector_names, selector; wait=true)

Delete named vector fields from selected points.
"""
function delete_vectors(c::Client, coll::AbstractString, names::AbstractVector{<:AbstractString},
                        sel::Union{AbstractVector{<:PointId}, PointId, Filter}; wait::Bool=true)
    body = merge(Dict{String,Any}("vector_names" => collect(names)), _selector(sel))
    _rp(HTTP.post, c, _pts_path(coll) * "/vectors/delete", body; query=_wait_q(wait))
end
delete_vectors(coll::AbstractString, names::AbstractVector{<:AbstractString}, sel; kw...) =
    delete_vectors(get_client(), coll, names, sel; kw...)

# ============================================================================
# Scroll & Count
# ============================================================================

"""
    scroll_points(client, collection; filter, limit, offset, with_vectors, with_payload)

Scroll through points with optional filtering.
"""
function scroll_points(c::Client, coll::AbstractString;
                       filter::Union{Nothing,Filter}=nothing,
                       limit::Int=10, offset=nothing,
                       with_vectors::Bool=false, with_payload::Bool=true)
    body = Dict{String,Any}("limit" => limit, "with_vectors" => with_vectors, "with_payload" => with_payload)
    filter !== nothing && (body["filter"] = todict(filter))
    offset !== nothing && (body["offset"] = offset)
    _rp(HTTP.post, c, _pts_path(coll) * "/scroll", body)
end
scroll_points(coll::AbstractString; kw...) = scroll_points(get_client(), coll; kw...)

"""
    count_points(client, collection; filter, exact)

Count points in a collection.
"""
function count_points(c::Client, coll::AbstractString;
                      filter::Union{Nothing,Filter}=nothing, exact::Bool=false)
    body = Dict{String,Any}("exact" => exact)
    filter !== nothing && (body["filter"] = todict(filter))
    _rp(HTTP.post, c, _pts_path(coll) * "/count", body)
end
count_points(coll::AbstractString; kw...) = count_points(get_client(), coll; kw...)

# ============================================================================
# Batch
# ============================================================================

"""
    batch_points(client, collection, operations; wait=true)

Execute multiple point operations in a single batch call.
"""
function batch_points(c::Client, coll::AbstractString, ops::AbstractVector; wait::Bool=true)
    body = Dict{String,Any}("operations" => ops)
    _rp(HTTP.post, c, _pts_path(coll) * "/batch", body; query=_wait_q(wait))
end
batch_points(coll::AbstractString, ops::AbstractVector; kw...) =
    batch_points(get_client(), coll, ops; kw...)
