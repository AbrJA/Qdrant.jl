# ============================================================================
# gRPC Points API — dispatch on GRPCTransport
# ============================================================================

# ── Upsert Points ────────────────────────────────────────────────────────

function upsert_points(c::QdrantConnection, collection::AbstractString,
                       points::AbstractVector{<:Point}, ::Val{:grpc};
                       wait::Bool=true, ordering::AbstractString="weak")
    transport = c.transport::GRPCTransport
    proto_points = qdrant.PointStruct[to_proto_point(p) for p in points]
    req = qdrant.UpsertPoints(
        collection,
        wait,
        proto_points,
        to_proto_ordering(ordering),
        nothing,  # shard_key_selector
        nothing,  # update_filter
        UInt64(0),  # timeout
        qdrant.UpdateMode.Upsert,  # update_mode
    )
    resp = grpc_request(transport, Points_Upsert_Client, req)
    _operation_response_to_dict(resp)
end

function _operation_response_to_dict(resp::qdrant.PointsOperationResponse)
    result = Dict{String,Any}("time" => resp.time)
    if resp.result !== nothing
        result["status"] = string(resp.result.status)
    end
    result
end

# ── Delete Points ────────────────────────────────────────────────────────

function delete_points(c::QdrantConnection, collection::AbstractString,
                       selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                       ::Val{:grpc};
                       wait::Bool=true)
    transport = c.transport::GRPCTransport
    req = qdrant.DeletePoints(
        collection,
        wait,
        to_proto_points_selector(selector),
        nothing,  # ordering
        nothing,  # shard_key_selector
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_Delete_Client, req)
    _operation_response_to_dict(resp)
end

# ── Get Points ───────────────────────────────────────────────────────────

function get_points(c::QdrantConnection, collection::AbstractString,
                    ids::AbstractVector{<:PointId}, ::Val{:grpc};
                    with_vectors::Bool=false, with_payload::Bool=true)
    transport = c.transport::GRPCTransport
    proto_ids = qdrant.PointId[to_proto_point_id(id) for id in ids]
    req = qdrant.GetPoints(
        collection,
        proto_ids,
        to_proto_with_payload(with_payload),
        to_proto_with_vectors(with_vectors),
        nothing,  # read_consistency
        nothing,  # shard_key_selector
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_Get_Client, req)
    [from_proto_retrieved_point(rp) for rp in resp.result]
end

# ── Set Payload ──────────────────────────────────────────────────────────

function set_payload(c::QdrantConnection, collection::AbstractString,
                     payload::AbstractDict,
                     selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                     ::Val{:grpc};
                     wait::Bool=true)
    transport = c.transport::GRPCTransport
    proto_payload = to_proto_payload(payload)
    points_selector = if selector isa Filter
        to_proto_points_selector(selector)
    elseif selector isa PointId
        to_proto_points_selector([selector])
    else
        to_proto_points_selector(selector)
    end
    req = qdrant.SetPayloadPoints(
        collection,
        wait,
        proto_payload,
        points_selector,
        nothing,  # ordering
        nothing,  # shard_key_selector
        "",       # key
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_SetPayload_Client, req)
    _operation_response_to_dict(resp)
end

# ── Delete Payload ───────────────────────────────────────────────────────

function delete_payload(c::QdrantConnection, collection::AbstractString,
                        keys::AbstractVector{<:AbstractString},
                        selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                        ::Val{:grpc};
                        wait::Bool=true)
    transport = c.transport::GRPCTransport
    points_selector = if selector isa Filter
        to_proto_points_selector(selector)
    elseif selector isa PointId
        to_proto_points_selector([selector])
    else
        to_proto_points_selector(selector)
    end
    req = qdrant.DeletePayloadPoints(
        collection,
        wait,
        String.(keys),
        points_selector,
        nothing,  # ordering
        nothing,  # shard_key_selector
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_DeletePayload_Client, req)
    _operation_response_to_dict(resp)
end

# ── Clear Payload ────────────────────────────────────────────────────────

function clear_payload(c::QdrantConnection, collection::AbstractString,
                       selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                       ::Val{:grpc};
                       wait::Bool=true)
    transport = c.transport::GRPCTransport
    req = qdrant.ClearPayloadPoints(
        collection,
        wait,
        to_proto_points_selector(selector),
        nothing,  # ordering
        nothing,  # shard_key_selector
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_ClearPayload_Client, req)
    _operation_response_to_dict(resp)
end

# ── Update Vectors ───────────────────────────────────────────────────────

function update_vectors(c::QdrantConnection, collection::AbstractString,
                        points::AbstractVector, ::Val{:grpc};
                        wait::Bool=true)
    transport = c.transport::GRPCTransport
    proto_points = qdrant.PointVectors[]
    for p in points
        id = to_proto_point_id(p isa AbstractDict ? p["id"] : p.id)
        vec = p isa AbstractDict ? p["vector"] : p.vector
        vectors = to_proto_vectors(vec)
        push!(proto_points, qdrant.PointVectors(id, vectors))
    end
    req = qdrant.UpdatePointVectors(
        collection,
        wait,
        proto_points,
        nothing,  # ordering
        nothing,  # shard_key_selector
        nothing,  # update_filter
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_UpdateVectors_Client, req)
    _operation_response_to_dict(resp)
end

# ── Delete Vectors ───────────────────────────────────────────────────────

function delete_vectors(c::QdrantConnection, collection::AbstractString,
                        names::AbstractVector{<:AbstractString},
                        selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                        ::Val{:grpc};
                        wait::Bool=true)
    transport = c.transport::GRPCTransport
    req = qdrant.DeletePointVectors(
        collection,
        wait,
        to_proto_points_selector(selector),
        qdrant.VectorsSelector(String.(names)),
        nothing,  # ordering
        nothing,  # shard_key_selector
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_DeleteVectors_Client, req)
    _operation_response_to_dict(resp)
end

# ── Scroll Points ────────────────────────────────────────────────────────

function scroll_points(c::QdrantConnection, collection::AbstractString,
                       ::Val{:grpc};
                       filter::Optional{Filter}=nothing,
                       limit::Int=10, offset=nothing,
                       with_vectors::Bool=false, with_payload::Bool=true)
    transport = c.transport::GRPCTransport
    proto_offset = nothing
    if offset !== nothing
        proto_offset = to_proto_point_id(offset isa PointId ? offset : Int(offset))
    end
    req = qdrant.ScrollPoints(
        collection,
        to_proto_filter(filter),
        proto_offset,
        UInt32(limit),
        to_proto_with_payload(with_payload),
        to_proto_with_vectors(with_vectors),
        nothing,  # read_consistency
        nothing,  # shard_key_selector
        nothing,  # order_by
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_Scroll_Client, req)
    result = Dict{String,Any}(
        "points" => [from_proto_retrieved_point(rp) for rp in resp.result],
    )
    resp.next_page_offset !== nothing && (result["next_page_offset"] = from_proto_point_id(resp.next_page_offset))
    result
end

# ── Count Points ─────────────────────────────────────────────────────────

function count_points(c::QdrantConnection, collection::AbstractString,
                      ::Val{:grpc};
                      filter::Optional{Filter}=nothing, exact::Bool=false)
    transport = c.transport::GRPCTransport
    req = qdrant.CountPoints(
        collection,
        to_proto_filter(filter),
        exact,
        nothing,  # read_consistency
        nothing,  # shard_key_selector
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_Count_Client, req)
    Dict{String,Any}("count" => Int(resp.result.count))
end

# ── Create Field Index ───────────────────────────────────────────────────

function create_payload_index(c::QdrantConnection, collection::AbstractString,
                              field_name::AbstractString, ::Val{:grpc};
                              field_schema::Union{String, AbstractQdrantType, AbstractDict, Nothing}=nothing,
                              wait::Bool=true)
    transport = c.transport::GRPCTransport
    field_type = qdrant.FieldType.FieldTypeKeyword
    field_index_params = nothing
    if field_schema isa String
        ft = _string_to_field_type(field_schema)
        ft !== nothing && (field_type = ft)
    elseif field_schema isa TextIndexParams
        field_type = qdrant.var"FieldType".FieldTypeText
        field_index_params = qdrant.PayloadIndexParams(OneOf(:text_index_params,
            qdrant.TextIndexParams(
                field_schema.tokenizer !== nothing ? _string_to_tokenizer(field_schema.tokenizer) :
                    qdrant.var"TokenizerType".Whitespace,
                field_schema.lowercase !== nothing ? field_schema.lowercase : false,
                field_schema.min_token_len !== nothing ? UInt64(field_schema.min_token_len) : UInt64(0),
                field_schema.max_token_len !== nothing ? UInt64(field_schema.max_token_len) : UInt64(0),
                false,  # on_disk
                nothing,  # stopwords
                false,  # phrase_matching
                nothing,  # stemmer
                false,  # ascii_folding
                false,  # enable_hnsw
            )))
    end
    req = qdrant.CreateFieldIndexCollection(
        collection,
        wait,
        field_name,
        field_type,
        field_index_params,
        nothing,  # ordering
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_CreateFieldIndex_Client, req)
    _operation_response_to_dict(resp)
end

function _string_to_field_type(s::AbstractString)
    s == "keyword" && return qdrant.var"FieldType".FieldTypeKeyword
    s == "integer" && return qdrant.var"FieldType".FieldTypeInteger
    s == "float"   && return qdrant.var"FieldType".FieldTypeFloat
    s == "geo"     && return qdrant.var"FieldType".FieldTypeGeo
    s == "text"    && return qdrant.var"FieldType".FieldTypeText
    s == "bool"    && return qdrant.var"FieldType".FieldTypeBool
    s == "datetime" && return qdrant.var"FieldType".FieldTypeDatetime
    s == "uuid"    && return qdrant.var"FieldType".FieldTypeUuid
    nothing
end

function _string_to_tokenizer(s::AbstractString)
    s == "word"         && return qdrant.var"TokenizerType".Word
    s == "whitespace"   && return qdrant.var"TokenizerType".Whitespace
    s == "prefix"       && return qdrant.var"TokenizerType".Prefix
    s == "multilingual" && return qdrant.var"TokenizerType".Multilingual
    qdrant.var"TokenizerType".Whitespace
end

# ── Delete Field Index ───────────────────────────────────────────────────

function delete_payload_index(c::QdrantConnection, collection::AbstractString,
                              field_name::AbstractString, ::Val{:grpc};
                              wait::Bool=true)
    transport = c.transport::GRPCTransport
    req = qdrant.DeleteFieldIndexCollection(
        collection,
        wait,
        field_name,
        nothing,  # ordering
        UInt64(0),  # timeout
    )
    resp = grpc_request(transport, Points_DeleteFieldIndex_Client, req)
    _operation_response_to_dict(resp)
end
