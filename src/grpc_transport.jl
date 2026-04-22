# ============================================================================
# gRPC Transport Layer
# ============================================================================

using gRPCClient
using ProtoBuf

# Load generated protobuf stubs
include(joinpath(@__DIR__, "gen", "qdrant", "qdrant.jl"))

# Import the generated qdrant module into our namespace
using .qdrant

# ============================================================================
# gRPC Transport Type
# ============================================================================

"""
    GRPCTransport <: AbstractTransport

gRPC transport using gRPCClient.jl with HTTP/2 and Protocol Buffers.
Provides ~2-10x faster throughput than REST for bulk operations.

# Fields
- `host`: Server hostname (default: "localhost")
- `port`: gRPC port (default: 6334)
- `api_key`: Optional API key for authentication
- `timeout`: Request deadline in seconds (default: 30)
- `tls`: Use TLS/gRPCS (default: false)
- `keepalive`: TCP keepalive interval in seconds (default: 60)
- `max_message_size`: Max message size in bytes (default: 64MB)
"""
mutable struct GRPCTransport <: AbstractTransport
    host::String
    port::Int
    api_key::Optional{String}
    timeout::Int
    tls::Bool
    keepalive::Int
    max_message_size::Int
    grpc_handle::Any  # gRPCCURL handle, lazily initialized
end

function GRPCTransport(;
    host::String="localhost",
    port::Int=6334,
    api_key::Optional{String}=nothing,
    timeout::Int=30,
    tls::Bool=false,
    keepalive::Int=60,
    max_message_size::Int=64*1024*1024,
)
    GRPCTransport(host, port, api_key, timeout, tls, keepalive, max_message_size, nothing)
end

function ensure_grpc_handle!(transport::GRPCTransport)
    if transport.grpc_handle === nothing
        transport.grpc_handle = gRPCClient.gRPCCURL()
        gRPCClient.grpc_init(transport.grpc_handle)
    end
    transport.grpc_handle
end

function grpc_client_kwargs(transport::GRPCTransport)
    Dict{Symbol,Any}(
        :secure => transport.tls,
        :grpc => ensure_grpc_handle!(transport),
        :deadline => transport.timeout,
        :keepalive => transport.keepalive,
        :max_send_message_length => transport.max_message_size,
        :max_recieve_message_length => transport.max_message_size,
    )
end

"""
    grpc_request(transport, ClientConstructor, request) -> response

Execute a synchronous gRPC request with error handling.
"""
function grpc_request(transport::GRPCTransport, client_ctor, request)
    kw = grpc_client_kwargs(transport)
    client = client_ctor(transport.host, transport.port; kw...)
    try
        resp = gRPCClient.grpc_sync_request(client, request)
        resp
    catch e
        if e isa gRPCClient.gRPCServiceCallException
            throw(QdrantError(
                e.grpc_status,
                "gRPC error [$(e.grpc_status)]: $(e.message)",
            ))
        end
        rethrow()
    end
end

# ============================================================================
# Type Conversion: Julia API types → Protobuf messages
# ============================================================================

"""
    to_proto_point_id(id::PointId) -> qdrant.PointId

Convert a Julia PointId (Int or UUID) to a protobuf PointId.
"""
function to_proto_point_id(id::Int)
    qdrant.PointId(OneOf(:num, UInt64(id)))
end
function to_proto_point_id(id::UUID)
    qdrant.PointId(OneOf(:uuid, string(id)))
end

"""
    from_proto_point_id(id::qdrant.PointId) -> PointId

Convert a protobuf PointId back to a Julia PointId.
"""
function from_proto_point_id(id::qdrant.PointId)
    v = id.point_id_options
    if v.name === :num
        Int(v.value)
    else
        UUID(v.value)
    end
end

"""
    to_proto_distance(d::Distance) -> qdrant.var"Distance".T

Convert a Julia Distance enum to a protobuf Distance enum.
"""
function to_proto_distance(d::Distance)
    d == Cosine    && return qdrant.var"Distance".Cosine
    d == Euclid    && return qdrant.var"Distance".Euclid
    d == Dot       && return qdrant.var"Distance".Dot
    d == Manhattan && return qdrant.var"Distance".Manhattan
    error("Unknown distance: $d")
end

"""
    from_proto_distance(d) -> Distance

Convert a protobuf Distance enum back to Julia Distance.
"""
function from_proto_distance(d)
    d == qdrant.var"Distance".Cosine    && return Cosine
    d == qdrant.var"Distance".Euclid    && return Euclid
    d == qdrant.var"Distance".Dot       && return Dot
    d == qdrant.var"Distance".Manhattan && return Manhattan
    error("Unknown proto distance: $d")
end

"""
    julia_value_to_proto(val) -> qdrant.Value

Convert a Julia value to a protobuf Value (json_with_int).
"""
function julia_value_to_proto(val::Nothing)
    qdrant.Value(OneOf(:null_value, qdrant.var"NullValue".NULL_VALUE))
end
function julia_value_to_proto(val::Bool)
    qdrant.Value(OneOf(:bool_value, val))
end
function julia_value_to_proto(val::Integer)
    qdrant.Value(OneOf(:integer_value, Int64(val)))
end
function julia_value_to_proto(val::AbstractFloat)
    qdrant.Value(OneOf(:double_value, Float64(val)))
end
function julia_value_to_proto(val::AbstractString)
    qdrant.Value(OneOf(:string_value, String(val)))
end
function julia_value_to_proto(val::AbstractVector)
    qdrant.Value(OneOf(:list_value, qdrant.ListValue(
        qdrant.Value[julia_value_to_proto(v) for v in val]
    )))
end
function julia_value_to_proto(val::AbstractDict)
    qdrant.Value(OneOf(:struct_value, qdrant.Struct(
        Dict{String,qdrant.Value}(String(k) => julia_value_to_proto(v) for (k, v) in val)
    )))
end

"""
    proto_value_to_julia(val::qdrant.Value) -> Any

Convert a protobuf Value back to a native Julia value.
"""
function proto_value_to_julia(val::qdrant.Value)
    v = val.kind
    v.name === :null_value    && return nothing
    v.name === :bool_value    && return v.value
    v.name === :integer_value && return Int(v.value)
    v.name === :double_value  && return v.value
    v.name === :string_value  && return v.value
    v.name === :list_value    && return Any[proto_value_to_julia(x) for x in v.value.values]
    v.name === :struct_value  && return Dict{String,Any}(k => proto_value_to_julia(vv) for (k, vv) in v.value.fields)
    error("Unknown proto value kind: $(v.name)")
end

"""
    to_proto_payload(payload) -> Dict{String,qdrant.Value}
"""
function to_proto_payload(payload::Nothing)
    Dict{String,qdrant.Value}()
end
function to_proto_payload(payload::AbstractDict)
    Dict{String,qdrant.Value}(String(k) => julia_value_to_proto(v) for (k, v) in payload)
end

"""
    from_proto_payload(payload) -> Dict{String,Any}
"""
function from_proto_payload(payload::Dict{String,qdrant.Value})
    Dict{String,Any}(k => proto_value_to_julia(v) for (k, v) in payload)
end

"""
    to_proto_vectors(vector) -> qdrant.Vectors

Convert Julia vector data to protobuf Vectors.
"""
function to_proto_vectors(v::AbstractVector{<:AbstractFloat})
    qdrant.Vectors(OneOf(:vector, qdrant.var"#Vector"(
        Float32[], nothing, UInt32(0),
        OneOf(:dense, qdrant.DenseVector(Float32.(v)))
    )))
end
function to_proto_vectors(v::NamedVector)
    named = qdrant.NamedVectors(Dict{String,qdrant.var"#Vector"}(
        v.name => qdrant.var"#Vector"(
            Float32[], nothing, UInt32(0),
            OneOf(:dense, qdrant.DenseVector(Float32.(v.vector)))
        )
    ))
    qdrant.Vectors(OneOf(:vectors, named))
end
function to_proto_vectors(v::AbstractDict{String,<:AbstractVector{<:AbstractFloat}})
    named = qdrant.NamedVectors(Dict{String,qdrant.var"#Vector"}(
        name => qdrant.var"#Vector"(
            Float32[], nothing, UInt32(0),
            OneOf(:dense, qdrant.DenseVector(Float32.(vec)))
        )
        for (name, vec) in v
    ))
    qdrant.Vectors(OneOf(:vectors, named))
end

"""
    from_proto_vectors(v::qdrant.VectorsOutput) -> Any

Convert protobuf VectorsOutput back to Julia.
"""
function from_proto_vectors(v::Nothing)
    nothing
end
function from_proto_vectors(v::qdrant.VectorsOutput)
    opt = v.vectors_options
    if opt.name === :vector
        vo = opt.value
        vv = vo.vector
        if vv.name === :dense
            return vv.value.data
        elseif vv.name === :sparse
            return Dict("values" => vv.value.values, "indices" => vv.value.indices)
        elseif vv.name === :multi_dense
            return [dv.data for dv in vv.value.vectors]
        end
        return Float32[]
    elseif opt.name === :vectors
        result = Dict{String,Any}()
        for (name, vo) in opt.value.vectors
            vv = vo.vector
            if vv.name === :dense
                result[name] = vv.value.data
            elseif vv.name === :sparse
                result[name] = Dict("values" => vv.value.values, "indices" => vv.value.indices)
            elseif vv.name === :multi_dense
                result[name] = [dv.data for dv in vv.value.vectors]
            end
        end
        return result
    end
    nothing
end

"""
    to_proto_point(p::Point) -> qdrant.PointStruct
"""
function to_proto_point(p::Point)
    qdrant.PointStruct(
        to_proto_point_id(p.id),
        to_proto_payload(p.payload),
        to_proto_vectors(p.vector),
    )
end

"""
    from_proto_scored_point(sp::qdrant.ScoredPoint) -> Dict{String,Any}
"""
function from_proto_scored_point(sp::qdrant.ScoredPoint)
    result = Dict{String,Any}(
        "id" => from_proto_point_id(sp.id),
        "score" => sp.score,
        "version" => Int(sp.version),
    )
    !isempty(sp.payload) && (result["payload"] = from_proto_payload(sp.payload))
    sp.vectors !== nothing && (result["vector"] = from_proto_vectors(sp.vectors))
    result
end

"""
    from_proto_retrieved_point(rp::qdrant.RetrievedPoint) -> Dict{String,Any}
"""
function from_proto_retrieved_point(rp::qdrant.RetrievedPoint)
    result = Dict{String,Any}(
        "id" => from_proto_point_id(rp.id),
    )
    !isempty(rp.payload) && (result["payload"] = from_proto_payload(rp.payload))
    rp.vectors !== nothing && (result["vector"] = from_proto_vectors(rp.vectors))
    result
end

# ============================================================================
# Filter Conversion
# ============================================================================

"""
    to_proto_match(m::AbstractCondition) -> qdrant.Match
"""
function to_proto_match(m::MatchValue)
    v = m.value
    if v isa String
        qdrant.Match(OneOf(:keyword, v))
    elseif v isa Integer
        qdrant.Match(OneOf(:integer, Int64(v)))
    elseif v isa Bool
        qdrant.Match(OneOf(:boolean, v))
    else
        qdrant.Match(OneOf(:keyword, string(v)))
    end
end
function to_proto_match(m::MatchText)
    qdrant.Match(OneOf(:text, m.text))
end
function to_proto_match(m::MatchAny)
    vals = m.any
    if !isempty(vals) && first(vals) isa AbstractString
        qdrant.Match(OneOf(:keywords, qdrant.RepeatedStrings(String.(vals))))
    else
        qdrant.Match(OneOf(:integers, qdrant.RepeatedIntegers(Int64.(vals))))
    end
end

"""
    to_proto_condition(fc::FieldCondition) -> qdrant.Condition
"""
function to_proto_condition(fc::FieldCondition)
    field = qdrant.FieldCondition(fc.key,
        fc.match !== nothing ? to_proto_match(fc.match) : nothing,
        fc.range !== nothing ? qdrant.Range(
            fc.range.lt !== nothing ? Float64(fc.range.lt) : 0.0,
            fc.range.gt !== nothing ? Float64(fc.range.gt) : 0.0,
            fc.range.gte !== nothing ? Float64(fc.range.gte) : 0.0,
            fc.range.lte !== nothing ? Float64(fc.range.lte) : 0.0,
        ) : nothing,
        nothing, nothing, nothing, nothing, nothing, false, false,
    )
    qdrant.Condition(OneOf(:field, field))
end
function to_proto_condition(hc::HasIdCondition)
    ids = qdrant.PointId[to_proto_point_id(id) for id in hc.has_id]
    qdrant.Condition(OneOf(:has_id, qdrant.HasIdCondition(ids)))
end
function to_proto_condition(ic::IsEmptyCondition)
    key = get(ic.is_empty, "key", "")
    qdrant.Condition(OneOf(:is_empty, qdrant.IsEmptyCondition(key)))
end
function to_proto_condition(ic::IsNullCondition)
    key = get(ic.is_null, "key", "")
    qdrant.Condition(OneOf(:is_null, qdrant.IsNullCondition(key)))
end

function to_proto_condition(d::AbstractDict)
    if haskey(d, "key")
        fc_match = nothing
        fc_range = nothing
        if haskey(d, "match")
            m = d["match"]
            if haskey(m, "value")
                fc_match = to_proto_match(MatchValue(value=m["value"]))
            elseif haskey(m, "text")
                fc_match = to_proto_match(MatchText(text=m["text"]))
            elseif haskey(m, "any")
                fc_match = to_proto_match(MatchAny(any=m["any"]))
            end
        end
        if haskey(d, "range")
            r = d["range"]
            fc_range = qdrant.Range(
                get(r, "lt", 0.0),
                get(r, "gt", 0.0),
                get(r, "gte", 0.0),
                get(r, "lte", 0.0),
            )
        end
        field = qdrant.FieldCondition(d["key"], fc_match, fc_range,
            nothing, nothing, nothing, nothing, nothing, false, false)
        return qdrant.Condition(OneOf(:field, field))
    elseif haskey(d, "has_id")
        ids = qdrant.PointId[to_proto_point_id(id) for id in d["has_id"]]
        return qdrant.Condition(OneOf(:has_id, qdrant.HasIdCondition(ids)))
    elseif haskey(d, "is_empty")
        key = d["is_empty"]["key"]
        return qdrant.Condition(OneOf(:is_empty, qdrant.IsEmptyCondition(key)))
    elseif haskey(d, "is_null")
        key = d["is_null"]["key"]
        return qdrant.Condition(OneOf(:is_null, qdrant.IsNullCondition(key)))
    end
    error("Unknown condition format: $d")
end

function _convert_conditions(conds)
    conds === nothing && return qdrant.Condition[]
    qdrant.Condition[to_proto_condition(c) for c in conds]
end

"""
    to_proto_filter(f::Filter) -> qdrant.Filter
"""
function to_proto_filter(f::Nothing)
    nothing
end
function to_proto_filter(f::Filter)
    qdrant.Filter(
        _convert_conditions(f.should),
        _convert_conditions(f.must),
        _convert_conditions(f.must_not),
        nothing,
    )
end

# ============================================================================
# WithPayloadSelector / WithVectorsSelector
# ============================================================================

function to_proto_with_payload(wp::Nothing)
    nothing
end
function to_proto_with_payload(wp::Bool)
    qdrant.WithPayloadSelector(OneOf(:enable, wp))
end
function to_proto_with_payload(wp::Vector{String})
    qdrant.WithPayloadSelector(OneOf(:include, qdrant.PayloadIncludeSelector(wp)))
end

function to_proto_with_vectors(wv::Nothing)
    nothing
end
function to_proto_with_vectors(wv::Bool)
    qdrant.WithVectorsSelector(OneOf(:enable, wv))
end
function to_proto_with_vectors(wv::Vector{String})
    qdrant.WithVectorsSelector(OneOf(:include, qdrant.VectorsSelector(wv)))
end

# ============================================================================
# SearchParams conversion
# ============================================================================

function to_proto_search_params(p::Nothing)
    nothing
end
function to_proto_search_params(p::SearchParams)
    quant = nothing
    if p.quantization !== nothing
        q = p.quantization
        quant = qdrant.QuantizationSearchParams(
            q.ignore !== nothing ? q.ignore : false,
            q.rescore !== nothing ? q.rescore : false,
            q.oversampling !== nothing ? q.oversampling : 0.0,
        )
    end
    qdrant.SearchParams(
        p.hnsw_ef !== nothing ? UInt64(p.hnsw_ef) : UInt64(0),
        p.exact !== nothing ? p.exact : false,
        quant,
        p.indexed_only !== nothing ? p.indexed_only : false,
        nothing,  # acorn
    )
end

# ============================================================================
# VectorParams conversion for collection creation
# ============================================================================

function to_proto_hnsw_config(h::Nothing)
    nothing
end
function to_proto_hnsw_config(h::HnswConfig)
    qdrant.HnswConfigDiff(
        h.m !== nothing ? UInt64(h.m) : UInt64(0),
        h.ef_construct !== nothing ? UInt64(h.ef_construct) : UInt64(0),
        h.full_scan_threshold !== nothing ? UInt64(h.full_scan_threshold) : UInt64(0),
        h.max_indexing_threads !== nothing ? UInt64(h.max_indexing_threads) : UInt64(0),
        h.on_disk !== nothing ? h.on_disk : false,
        h.payload_m !== nothing ? UInt64(h.payload_m) : UInt64(0),
        h.inline_storage !== nothing ? h.inline_storage : false,
    )
end

function to_proto_wal_config(w::Nothing)
    nothing
end
function to_proto_wal_config(w::WalConfig)
    qdrant.WalConfigDiff(
        w.wal_capacity_mb !== nothing ? UInt64(w.wal_capacity_mb) : UInt64(0),
        w.wal_segments_ahead !== nothing ? UInt64(w.wal_segments_ahead) : UInt64(0),
        w.wal_retain_closed !== nothing ? UInt64(w.wal_retain_closed) : UInt64(0),
    )
end

function to_proto_optimizers_config(o::Nothing)
    nothing
end
function to_proto_optimizers_config(o::OptimizersConfig)
    qdrant.OptimizersConfigDiff(
        o.deleted_threshold !== nothing ? o.deleted_threshold : 0.0,
        o.vacuum_min_vector_number !== nothing ? UInt64(o.vacuum_min_vector_number) : UInt64(0),
        o.default_segment_number !== nothing ? UInt64(o.default_segment_number) : UInt64(0),
        o.max_segment_size !== nothing ? UInt64(o.max_segment_size) : UInt64(0),
        o.memmap_threshold !== nothing ? UInt64(o.memmap_threshold) : UInt64(0),
        o.indexing_threshold !== nothing ? UInt64(o.indexing_threshold) : UInt64(0),
        o.flush_interval_sec !== nothing ? UInt64(o.flush_interval_sec) : UInt64(0),
        UInt64(0),  # deprecated max_optimization_threads
        nothing,  # max_optimization_threads wrapper
        o.prevent_unoptimized !== nothing ? o.prevent_unoptimized : false,
    )
end

function to_proto_vector_params(vp::VectorParams)
    qdrant.VectorParams(
        UInt64(vp.size),
        to_proto_distance(vp.distance),
        to_proto_hnsw_config(vp.hnsw_config),
        nothing,  # quantization_config
        vp.on_disk !== nothing ? vp.on_disk : false,
        vp.datatype !== nothing ? (
            vp.datatype == "float32" ? qdrant.var"Datatype".Float32 :
            vp.datatype == "uint8" ? qdrant.var"Datatype".Uint8 :
            vp.datatype == "float16" ? qdrant.var"Datatype".Float16 :
            qdrant.var"Datatype".Default
        ) : qdrant.var"Datatype".Default,
        nothing,  # multivector_config
    )
end

function to_proto_vectors_config(v::VectorParams)
    qdrant.VectorsConfig(OneOf(:params, to_proto_vector_params(v)))
end
function to_proto_vectors_config(v::Dict{String,VectorParams})
    params_map = qdrant.VectorParamsMap(
        Dict{String,qdrant.VectorParams}(name => to_proto_vector_params(vp) for (name, vp) in v)
    )
    qdrant.VectorsConfig(OneOf(:params_map, params_map))
end

# ============================================================================
# WriteOrdering
# ============================================================================

function to_proto_ordering(ordering::AbstractString)
    if ordering == "weak"
        qdrant.WriteOrdering(qdrant.var"WriteOrderingType".Weak)
    elseif ordering == "medium"
        qdrant.WriteOrdering(qdrant.var"WriteOrderingType".Medium)
    elseif ordering == "strong"
        qdrant.WriteOrdering(qdrant.var"WriteOrderingType".Strong)
    else
        qdrant.WriteOrdering(qdrant.var"WriteOrderingType".Weak)
    end
end

# ============================================================================
# Points selector conversion
# ============================================================================

function to_proto_points_selector(ids::AbstractVector{<:PointId})
    id_list = qdrant.PointsIdsList(qdrant.PointId[to_proto_point_id(id) for id in ids])
    qdrant.PointsSelector(OneOf(:points, id_list))
end
function to_proto_points_selector(id::PointId)
    to_proto_points_selector([id])
end
function to_proto_points_selector(f::Filter)
    qdrant.PointsSelector(OneOf(:filter, to_proto_filter(f)))
end
