# ============================================================================
# Abstract Type Hierarchy
# ============================================================================

"""
    AbstractQdrantType

Root of the Qdrant type hierarchy. Enables generic `todict` serialization.
"""
abstract type AbstractQdrantType end

"""
    AbstractConfig <: AbstractQdrantType

Configuration types for creating/updating resources.
"""
abstract type AbstractConfig <: AbstractQdrantType end

"""
    AbstractRequest <: AbstractQdrantType

Request types for search/query/recommend/discover endpoints.
"""
abstract type AbstractRequest <: AbstractQdrantType end

"""
    AbstractCondition <: AbstractQdrantType

Filter condition types.
"""
abstract type AbstractCondition <: AbstractQdrantType end

# ============================================================================
# Distance Enum
# ============================================================================

"""
    Distance

Vector distance metric.

Values: `Cosine`, `Euclid`, `Dot`, `Manhattan`

# Examples
```julia
VectorParams(size=128, distance=Cosine)
VectorParams(size=4, distance=Dot)
```
"""
@enum Distance Cosine Euclid Dot Manhattan

# ============================================================================
# Point Identity
# ============================================================================

"""
    PointId

A unique point identifier — integer or UUID string.
"""
const PointId = Union{Int, String}

# ============================================================================
# Vector Parameters
# ============================================================================

"""
    VectorParams <: AbstractConfig

Configuration for a vector field in a collection.

# Examples
```julia
VectorParams(size=128, distance=Cosine)
VectorParams(size=4, distance=Dot, on_disk=true)
```
"""
Base.@kwdef struct VectorParams <: AbstractConfig
    size::Int
    distance::Distance
    hnsw_config::Union{Nothing, Dict} = nothing
    quantization_config::Union{Nothing, Dict} = nothing
    on_disk::Union{Nothing, Bool} = nothing
end

"""
    SparseVectorParams <: AbstractConfig

Configuration for sparse vector fields.
"""
Base.@kwdef struct SparseVectorParams <: AbstractConfig
    index::Bool
end

# ============================================================================
# Collection Types
# ============================================================================

"""
    CollectionConfig <: AbstractConfig

Configuration for creating a collection.

# Examples
```julia
CollectionConfig(vectors=VectorParams(size=128, distance=Cosine))
CollectionConfig(vectors=VectorParams(size=4, distance=Dot), on_disk_payload=true)
```
"""
Base.@kwdef struct CollectionConfig <: AbstractConfig
    vectors::Union{VectorParams, Dict}
    sparse_vectors::Union{Nothing, Dict} = nothing
    shard_number::Union{Nothing, Int} = nothing
    replication_factor::Union{Nothing, Int} = nothing
    write_consistency_factor::Union{Nothing, Int} = nothing
    on_disk_payload::Union{Nothing, Bool} = nothing
    hnsw_config::Union{Nothing, Dict} = nothing
    wal_config::Union{Nothing, Dict} = nothing
    optimizers_config::Union{Nothing, Dict} = nothing
    init_from::Union{Nothing, Dict} = nothing
end

"""
    CollectionUpdate <: AbstractConfig

Patch payload for updating collection parameters.
"""
Base.@kwdef struct CollectionUpdate <: AbstractConfig
    optimizers_config::Union{Nothing, Dict} = nothing
    params::Union{Nothing, Dict} = nothing
end

# ============================================================================
# Points
# ============================================================================

"""
    PointStruct <: AbstractQdrantType

A point with id, vector(s), and optional payload.

# Examples
```julia
PointStruct(id=1, vector=Float32[0.1, 0.2, 0.3], payload=Dict("label" => "cat"))
```
"""
Base.@kwdef struct PointStruct <: AbstractQdrantType
    id::PointId
    vector::Union{Vector{Float32}, Dict{String, Vector{Float32}}}
    payload::Union{Nothing, Dict} = nothing
end

# ============================================================================
# Filters & Conditions
# ============================================================================

"""
    Filter <: AbstractCondition

Compound filter with `must`, `should`, `must_not` clauses.

# Examples
```julia
Filter(must=[Dict("key" => "color", "match" => Dict("value" => "red"))])
```
"""
Base.@kwdef struct Filter <: AbstractCondition
    must::Union{Nothing, Vector{Dict}} = nothing
    should::Union{Nothing, Vector{Dict}} = nothing
    must_not::Union{Nothing, Vector{Dict}} = nothing
end

"""
    FieldCondition <: AbstractCondition

Condition on a specific payload field.
"""
Base.@kwdef struct FieldCondition <: AbstractCondition
    key::String
    range::Union{Nothing, Dict} = nothing
    match::Union{Nothing, Dict} = nothing
    geo_bounding_box::Union{Nothing, Dict} = nothing
    geo_radius::Union{Nothing, Dict} = nothing
    geo_polygon::Union{Nothing, Dict} = nothing
    values_count::Union{Nothing, Dict} = nothing
end

"""
    MatchValue <: AbstractCondition

Match a specific value.
"""
Base.@kwdef struct MatchValue <: AbstractCondition
    value::Union{String, Int, Float64, Bool}
end

"""
    RangeCondition <: AbstractCondition

Range comparison filter.
"""
Base.@kwdef struct RangeCondition <: AbstractCondition
    gte::Union{Nothing, Float64} = nothing
    gt::Union{Nothing, Float64} = nothing
    lte::Union{Nothing, Float64} = nothing
    lt::Union{Nothing, Float64} = nothing
end

"""
    HasIdCondition <: AbstractCondition

Filter points by ID.
"""
Base.@kwdef struct HasIdCondition <: AbstractCondition
    has_id::Vector{PointId}
end

"""
    IsEmptyCondition <: AbstractCondition

Filter for empty fields.
"""
Base.@kwdef struct IsEmptyCondition <: AbstractCondition
    is_empty::Dict
end

"""
    IsNullCondition <: AbstractCondition

Filter for null fields.
"""
Base.@kwdef struct IsNullCondition <: AbstractCondition
    is_null::Dict
end

# ============================================================================
# Search / Recommend / Query / Discover Requests
# ============================================================================

"""
    SearchRequest <: AbstractRequest

Nearest-neighbor search request.

# Examples
```julia
SearchRequest(vector=Float32[1,0,0,0], limit=10)
SearchRequest(vector=Float32[1,0,0,0], limit=5, with_payload=true)
```
"""
Base.@kwdef struct SearchRequest <: AbstractRequest
    vector::Union{Vector{Float32}, String, Dict}
    limit::Int
    filter::Union{Nothing, Filter} = nothing
    offset::Union{Nothing, Int} = nothing
    with_payload::Union{Nothing, Bool, Vector{String}} = nothing
    with_vector::Union{Nothing, Bool, Vector{String}} = nothing
    score_threshold::Union{Nothing, Float32} = nothing
    vector_name::Union{Nothing, String} = nothing
    lookup_from::Union{Nothing, Dict} = nothing
    search_params::Union{Nothing, Dict} = nothing
end

"""
    RecommendRequest <: AbstractRequest

Recommendation request based on positive/negative examples.
"""
Base.@kwdef struct RecommendRequest <: AbstractRequest
    positive::Union{Nothing, Vector{PointId}} = nothing
    negative::Union{Nothing, Vector{PointId}} = nothing
    limit::Int
    filter::Union{Nothing, Filter} = nothing
    offset::Union{Nothing, Int} = nothing
    with_payload::Union{Nothing, Bool, Vector{String}} = nothing
    with_vector::Union{Nothing, Bool, Vector{String}} = nothing
    score_threshold::Union{Nothing, Float32} = nothing
    vector_name::Union{Nothing, String} = nothing
    lookup_from::Union{Nothing, Dict} = nothing
    search_params::Union{Nothing, Dict} = nothing
end

"""
    QueryRequest <: AbstractRequest

Advanced query request.
"""
Base.@kwdef struct QueryRequest <: AbstractRequest
    query::Union{Vector{Float32}, String, Dict}
    limit::Int
    filter::Union{Nothing, Filter} = nothing
    offset::Union{Nothing, Int} = nothing
    with_payload::Union{Nothing, Bool, Vector{String}} = nothing
    with_vector::Union{Nothing, Bool, Vector{String}} = nothing
    score_threshold::Union{Nothing, Float32} = nothing
end

"""
    DiscoverRequest <: AbstractRequest

Discovery request — find points near a target with optional context.
"""
Base.@kwdef struct DiscoverRequest <: AbstractRequest
    target::Union{PointId, Vector{Float32}, Dict}
    limit::Int
    context::Union{Nothing, Vector{Dict}} = nothing
    filter::Union{Nothing, Filter} = nothing
    offset::Union{Nothing, Int} = nothing
    with_payload::Union{Nothing, Bool, Vector{String}} = nothing
    with_vector::Union{Nothing, Bool, Vector{String}} = nothing
end
