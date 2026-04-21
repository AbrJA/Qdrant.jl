# ============================================================================
# Type Aliases
# ============================================================================

"""
    Optional{T}

Alias for `Union{Nothing, T}`. Used throughout for optional fields.
"""
const Optional{T} = Union{Nothing, T}

"""
    PointId

A unique point identifier — integer or UUID string.
"""
const PointId = Union{Int, String}

# ============================================================================
# Abstract Type Hierarchy
# ============================================================================

"""
    AbstractQdrantType

Root of the Qdrant type hierarchy. All Qdrant structs subtype this.
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
"""
@enum Distance Cosine Euclid Dot Manhattan

# StructUtils integration: serialize enum as string name
StructUtils.lower(d::Distance) = string(d)

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
StructUtils.@kwarg struct VectorParams <: AbstractConfig
    size::Int
    distance::Distance
    hnsw_config::Optional{Dict{String,Any}} = nothing
    quantization_config::Optional{Dict{String,Any}} = nothing
    on_disk::Optional{Bool} = nothing
end

"""
    SparseVectorParams <: AbstractConfig

Configuration for sparse vector fields.
"""
StructUtils.@kwarg struct SparseVectorParams <: AbstractConfig
    index::Optional{Dict{String,Any}} = nothing
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
StructUtils.@kwarg struct CollectionConfig <: AbstractConfig
    vectors::Union{VectorParams, Dict{String,VectorParams}, Dict{String,Any}}
    sparse_vectors::Optional{Dict{String,Any}} = nothing
    shard_number::Optional{Int} = nothing
    replication_factor::Optional{Int} = nothing
    write_consistency_factor::Optional{Int} = nothing
    on_disk_payload::Optional{Bool} = nothing
    hnsw_config::Optional{Dict{String,Any}} = nothing
    wal_config::Optional{Dict{String,Any}} = nothing
    optimizers_config::Optional{Dict{String,Any}} = nothing
    init_from::Optional{Dict{String,Any}} = nothing
    quantization_config::Optional{Dict{String,Any}} = nothing
    sharding_method::Optional{String} = nothing
end

"""
    CollectionUpdate <: AbstractConfig

Patch payload for updating collection parameters.
"""
StructUtils.@kwarg struct CollectionUpdate <: AbstractConfig
    optimizers_config::Optional{Dict{String,Any}} = nothing
    params::Optional{Dict{String,Any}} = nothing
    hnsw_config::Optional{Dict{String,Any}} = nothing
    quantization_config::Optional{Dict{String,Any}} = nothing
    vectors::Optional{Dict{String,Any}} = nothing
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
PointStruct(id="uuid-here", vector=Dict("image" => Float32[...], "text" => Float32[...]))
```
"""
StructUtils.@kwarg struct PointStruct <: AbstractQdrantType
    id::PointId
    vector::Union{Vector{Float32}, Vector{Float64}, Dict{String,Any}, Dict{String,Vector{Float32}}, Dict{String,Vector{Float64}}}
    payload::Optional{Dict{String,Any}} = nothing
end

# ============================================================================
# Filters & Conditions
# ============================================================================

"""
    MatchValue <: AbstractCondition

Match a specific value.
"""
StructUtils.@kwarg struct MatchValue <: AbstractCondition
    value::Union{String, Int, Float64, Bool}
end

"""
    MatchAny <: AbstractCondition

Match any of the given values.
"""
StructUtils.@kwarg struct MatchAny <: AbstractCondition
    any::Vector{Any}
end

"""
    MatchText <: AbstractCondition

Full-text match.
"""
StructUtils.@kwarg struct MatchText <: AbstractCondition
    text::String
end

"""
    RangeCondition <: AbstractCondition

Range comparison filter.
"""
StructUtils.@kwarg struct RangeCondition <: AbstractCondition
    gte::Optional{Float64} = nothing
    gt::Optional{Float64} = nothing
    lte::Optional{Float64} = nothing
    lt::Optional{Float64} = nothing
end

"""
    FieldCondition <: AbstractCondition

Condition on a specific payload field.
"""
StructUtils.@kwarg struct FieldCondition <: AbstractCondition
    key::String
    range::Optional{RangeCondition} = nothing
    match::Optional{Union{MatchValue, MatchAny, MatchText, Dict{String,Any}}} = nothing
    geo_bounding_box::Optional{Dict{String,Any}} = nothing
    geo_radius::Optional{Dict{String,Any}} = nothing
    geo_polygon::Optional{Dict{String,Any}} = nothing
    values_count::Optional{Dict{String,Any}} = nothing
end

"""
    HasIdCondition <: AbstractCondition

Filter points by ID.
"""
StructUtils.@kwarg struct HasIdCondition <: AbstractCondition
    has_id::Vector{PointId}
end

"""
    IsEmptyCondition <: AbstractCondition

Filter for empty fields.
"""
StructUtils.@kwarg struct IsEmptyCondition <: AbstractCondition
    is_empty::Dict{String,Any}
end

"""
    IsNullCondition <: AbstractCondition

Filter for null fields.
"""
StructUtils.@kwarg struct IsNullCondition <: AbstractCondition
    is_null::Dict{String,Any}
end

"""
    Filter <: AbstractCondition

Compound filter with `must`, `should`, `must_not` clauses.

# Examples
```julia
Filter(must=[Dict("key" => "color", "match" => Dict("value" => "red"))])
```
"""
StructUtils.@kwarg struct Filter <: AbstractCondition
    must::Optional{Vector{Any}} = nothing
    should::Optional{Vector{Any}} = nothing
    must_not::Optional{Vector{Any}} = nothing
    min_should::Optional{Dict{String,Any}} = nothing
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
StructUtils.@kwarg struct SearchRequest <: AbstractRequest
    vector::Union{Vector{Float32}, Vector{Float64}, String, Dict{String,Any}}
    limit::Int
    filter::Optional{Filter} = nothing
    offset::Optional{Int} = nothing
    with_payload::Optional{Union{Bool, Vector{String}}} = nothing
    with_vector::Optional{Union{Bool, Vector{String}}} = nothing
    score_threshold::Optional{Float64} = nothing
    lookup_from::Optional{Dict{String,Any}} = nothing
    params::Optional{Dict{String,Any}} = nothing
end

"""
    RecommendRequest <: AbstractRequest

Recommendation request based on positive/negative examples.
"""
StructUtils.@kwarg struct RecommendRequest <: AbstractRequest
    positive::Optional{Vector{Any}} = nothing
    negative::Optional{Vector{Any}} = nothing
    limit::Int
    filter::Optional{Filter} = nothing
    offset::Optional{Int} = nothing
    with_payload::Optional{Union{Bool, Vector{String}}} = nothing
    with_vector::Optional{Union{Bool, Vector{String}}} = nothing
    score_threshold::Optional{Float64} = nothing
    lookup_from::Optional{Dict{String,Any}} = nothing
    params::Optional{Dict{String,Any}} = nothing
    strategy::Optional{String} = nothing
    using_::Optional{String} = nothing &(name="using",)
end

"""
    QueryRequest <: AbstractRequest

Advanced query request (Qdrant universal query API).
"""
StructUtils.@kwarg struct QueryRequest <: AbstractRequest
    query::Optional{Union{Vector{Float32}, Vector{Float64}, String, Dict{String,Any}}} = nothing
    limit::Optional{Int} = nothing
    filter::Optional{Filter} = nothing
    offset::Optional{Int} = nothing
    with_payload::Optional{Union{Bool, Vector{String}}} = nothing
    with_vector::Optional{Union{Bool, Vector{String}}} = nothing
    score_threshold::Optional{Float64} = nothing
    using_::Optional{String} = nothing &(name="using",)
    prefetch::Optional{Union{Dict{String,Any}, Vector{Any}}} = nothing
    params::Optional{Dict{String,Any}} = nothing
end

"""
    DiscoverRequest <: AbstractRequest

Discovery request — find points near a target with optional context.
"""
StructUtils.@kwarg struct DiscoverRequest <: AbstractRequest
    target::Union{PointId, Vector{Float32}, Vector{Float64}, Dict{String,Any}}
    limit::Int
    context::Optional{Vector{Any}} = nothing
    filter::Optional{Filter} = nothing
    offset::Optional{Int} = nothing
    with_payload::Optional{Union{Bool, Vector{String}}} = nothing
    with_vector::Optional{Union{Bool, Vector{String}}} = nothing
end

# ============================================================================
# Payload Index Types
# ============================================================================

"""
    TextIndexParams <: AbstractConfig

Configuration for full-text index on a payload field.
"""
StructUtils.@kwarg struct TextIndexParams <: AbstractConfig
    type::String = "text"
    tokenizer::Optional{String} = nothing
    min_token_len::Optional{Int} = nothing
    max_token_len::Optional{Int} = nothing
    lowercase::Optional{Bool} = nothing
end
