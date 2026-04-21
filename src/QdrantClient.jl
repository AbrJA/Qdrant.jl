"""
    QdrantClient

A Julian client for the [Qdrant](https://qdrant.tech) vector database.

Uses abstract types and multiple dispatch for extensibility.
All API functions accept an explicit `Client` or fall back to `get_client()`.

# Quick Start
```julia
using QdrantClient

client = Client()
create_collection(client, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
upsert_points(client, "demo", [PointStruct(id=1, vector=Float32[1,0,0,0])])
search_points(client, "demo", SearchRequest(vector=Float32[1,0,0,0], limit=5))
```
"""
module QdrantClient

using HTTP
using JSON

const VERSION = "0.2.0"

# ── Error type ───────────────────────────────────────────────────────────
include("error.jl")

# ── Type hierarchy ───────────────────────────────────────────────────────
include("types.jl")

# ============================================================================
# Client
# ============================================================================

"""
    Client

Connection to a Qdrant server.

# Fields
- `host::String`: Server URL (default `"http://localhost"`)
- `port::Int`: Server port (default `6333`)
- `api_key::Union{String,Nothing}`: Optional API key
- `timeout::Int`: Request timeout in seconds (default `30`)
"""
Base.@kwdef mutable struct Client
    host::String = "http://localhost"
    port::Int = 6333
    api_key::Union{String,Nothing} = nothing
    timeout::Int = 30
    _pool::Union{HTTP.Pool,Nothing} = nothing
end

const _GLOBAL_CLIENT = Ref{Client}()

"""
    set_client!(c::Client) -> Client

Set the global default client.
"""
function set_client!(c::Client)
    _GLOBAL_CLIENT[] = c
    c
end

"""
    get_client() -> Client

Return the global default client, creating one if needed.
"""
function get_client()
    isassigned(_GLOBAL_CLIENT) || (_GLOBAL_CLIENT[] = Client())
    _GLOBAL_CLIENT[]
end

# ============================================================================
# Serialization — todict protocol
# ============================================================================

"""
    todict(x::AbstractQdrantType) -> Dict{Symbol,Any}

Recursively convert a Qdrant type to a `Dict`, dropping `nothing` fields.
Dispatch on `AbstractQdrantType` makes this extensible for user subtypes.
"""
function todict(x::AbstractQdrantType)
    d = Dict{Symbol,Any}()
    for f in fieldnames(typeof(x))
        v = getfield(x, f)
        v === nothing && continue
        d[f] = _serialize(v)
    end
    d
end

# Specialization: Distance enum serializes as its name string
todict(d::Distance) = string(d)

_serialize(v::AbstractQdrantType) = todict(v)
_serialize(d::Distance) = string(d)
_serialize(v::AbstractDict) = v
_serialize(v::AbstractString) = v
_serialize(v::Number) = v
_serialize(v::Bool) = v
_serialize(v::AbstractVector) = [_serialize(el) for el in v]
_serialize(v::Tuple) = [_serialize(el) for el in v]
_serialize(v) = v  # fallback

# ============================================================================
# HTTP internals
# ============================================================================

_pool!(c::Client) = (c._pool === nothing && (c._pool = HTTP.Pool()); c._pool)

function _url(c::Client, path::AbstractString)
    p = startswith(path, '/') ? path[2:end] : path
    "$(c.host):$(c.port)/$p"
end

function _headers(c::Client)
    h = ["Content-Type" => "application/json", "User-Agent" => "QdrantClient.jl/$VERSION"]
    c.api_key !== nothing && push!(h, "api-key" => c.api_key)
    h
end

function _parse_error(resp::HTTP.Response)
    body = String(resp.body)
    try
        parsed = JSON.parse(body; dicttype=Dict{Symbol,Any})
        st = get(parsed, :status, nothing)
        if st isa Dict && haskey(st, :error)
            return QdrantError(resp.status, st[:error], parsed)
        end
        return QdrantError(resp.status, "API error $(resp.status)", parsed)
    catch
        return QdrantError(resp.status, "API error $(resp.status): $(first(body, 200))")
    end
end

"""
    request(method, client, path, [body]; query=nothing) -> HTTP.Response

Low-level HTTP request with error handling and connection pooling.
"""
function request(method::Function, c::Client, path::AbstractString, body=nothing; query=nothing)
    url = _url(c, path)
    kw = Dict{Symbol,Any}(:pool => _pool!(c), :headers => _headers(c), :status_exception => false)
    query !== nothing && (kw[:query] = query)
    if body !== nothing
        kw[:body] = body isa AbstractString ? body : JSON.json(body)
    end
    resp = method(url; kw...)
    resp.status >= 400 && throw(_parse_error(resp))
    resp
end

"""
    parse_response(resp::HTTP.Response)

Parse the JSON response, unwrapping Qdrant's `{status, time, result}` envelope.
Returns `nothing` for empty bodies.
"""
function parse_response(resp::HTTP.Response)
    b = String(resp.body)
    isempty(b) && return nothing
    parsed = JSON.parse(b; dicttype=Dict{Symbol,Any})
    haskey(parsed, :result) ? parsed[:result] : parsed
end

# Convenience: request + parse in one step
function _rp(method::Function, c::Client, path::AbstractString, body=nothing; query=nothing)
    parse_response(request(method, c, path, body; query))
end

# ── API modules ──────────────────────────────────────────────────────────
include("collections.jl")
include("points.jl")
include("search.jl")
include("discovery.jl")
include("snapshots.jl")
include("distributed.jl")
include("service.jl")

# ============================================================================
# Exports
# ============================================================================

# Core
export Client, set_client!, get_client, QdrantError

# Type hierarchy
export AbstractQdrantType, AbstractConfig, AbstractRequest, AbstractCondition

# Enum & aliases
export Distance, Cosine, Euclid, Dot, Manhattan, PointId

# Config types
export CollectionConfig, CollectionUpdate, VectorParams, SparseVectorParams

# Point types
export PointStruct

# Conditions
export Filter, FieldCondition, MatchValue, RangeCondition,
       HasIdCondition, IsEmptyCondition, IsNullCondition

# Request types
export SearchRequest, RecommendRequest, QueryRequest, DiscoverRequest

# Serialization
export todict

# Collections API
export list_collections, create_collection, delete_collection,
       collection_exists, get_collection, update_collection,
       list_aliases, create_alias, delete_alias, rename_alias,
       list_collection_aliases

# Points API
export upsert_points, delete_points, get_points, set_payload,
       delete_payload, clear_payload, update_vectors, delete_vectors,
       scroll_points, count_points, batch_points

# Search API
export search_points, search_batch, search_groups,
       recommend_points, recommend_batch, recommend_groups,
       query_points, query_batch, query_groups

# Discovery API
export discover_points, discover_batch

# Snapshots API
export create_snapshot, list_snapshots, delete_snapshot

# Service API
export health_check, get_metrics, get_telemetry

# Distributed API
export cluster_status

end # module
