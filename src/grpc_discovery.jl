# ============================================================================
# gRPC Discovery API — dispatch on GRPCTransport
# ============================================================================

function discover_points(c::QdrantConnection, collection::AbstractString,
                         req::DiscoverRequest, ::Val{:grpc})
    transport = c.transport::GRPCTransport

    # Build target vector
    target = nothing
    if req.target !== nothing && req.target isa AbstractVector{<:AbstractFloat}
        dense = qdrant.DenseVector(Float32.(req.target))
        vi = qdrant.VectorInput(OneOf(:dense, dense))
        ve = qdrant.VectorExample(OneOf(:vector, qdrant.var"#Vector"(
            Float32[], nothing, UInt32(0), OneOf(:dense, dense)
        )))
        target = qdrant.TargetVector(OneOf(:single, ve))
    end

    # Build context pairs
    context_pairs = qdrant.ContextExamplePair[]
    if req.context !== nothing
        for ctx in req.context
            pos_id = ctx isa AbstractDict ? get(ctx, "positive", nothing) : nothing
            neg_id = ctx isa AbstractDict ? get(ctx, "negative", nothing) : nothing
            pos_ex = if pos_id !== nothing
                pid = to_proto_point_id(pos_id isa PointId ? pos_id : Int(pos_id))
                qdrant.VectorExample(OneOf(:id, pid))
            else
                qdrant.VectorExample(OneOf(:id, to_proto_point_id(1)))
            end
            neg_ex = if neg_id !== nothing
                nid = to_proto_point_id(neg_id isa PointId ? neg_id : Int(neg_id))
                qdrant.VectorExample(OneOf(:id, nid))
            else
                qdrant.VectorExample(OneOf(:id, to_proto_point_id(1)))
            end
            push!(context_pairs, qdrant.ContextExamplePair(pos_ex, neg_ex))
        end
    end

    proto_req = qdrant.DiscoverPoints(
        collection,                                    # collection_name
        target,                                        # target
        context_pairs,                                 # context
        to_proto_filter(req.filter),                   # filter
        UInt64(req.limit),                             # limit
        to_proto_with_payload(req.with_payload),       # with_payload
        to_proto_search_params(req.params),            # params
        req.offset !== nothing ? UInt64(req.offset) : UInt64(0),
        req.using_ !== nothing ? req.using_ : "",      # using
        to_proto_with_vectors(req.with_vector),        # with_vectors
        nothing,                                       # lookup_from
        nothing,                                       # read_consistency
        UInt64(0),                                     # timeout
        nothing,                                       # shard_key_selector
    )
    resp = grpc_request(transport, Points_Discover_Client, proto_req)
    [from_proto_scored_point(sp) for sp in resp.result]
end

function discover_batch(c::QdrantConnection, collection::AbstractString,
                        requests::AbstractVector{DiscoverRequest}, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    discover_list = qdrant.DiscoverPoints[]
    for req in requests
        target = nothing
        if req.target !== nothing && req.target isa AbstractVector{<:AbstractFloat}
            dense = qdrant.DenseVector(Float32.(req.target))
            ve = qdrant.VectorExample(OneOf(:vector, qdrant.var"#Vector"(
                Float32[], nothing, UInt32(0), OneOf(:dense, dense)
            )))
            target = qdrant.TargetVector(OneOf(:single, ve))
        end
        context_pairs = qdrant.ContextExamplePair[]
        if req.context !== nothing
            for ctx in req.context
                pos_id = ctx isa AbstractDict ? get(ctx, "positive", nothing) : nothing
                neg_id = ctx isa AbstractDict ? get(ctx, "negative", nothing) : nothing
                pos_ex = pos_id !== nothing ?
                    qdrant.VectorExample(OneOf(:id, to_proto_point_id(pos_id isa PointId ? pos_id : Int(pos_id)))) :
                    qdrant.VectorExample(OneOf(:id, to_proto_point_id(1)))
                neg_ex = neg_id !== nothing ?
                    qdrant.VectorExample(OneOf(:id, to_proto_point_id(neg_id isa PointId ? neg_id : Int(neg_id)))) :
                    qdrant.VectorExample(OneOf(:id, to_proto_point_id(1)))
                push!(context_pairs, qdrant.ContextExamplePair(pos_ex, neg_ex))
            end
        end
        push!(discover_list, qdrant.DiscoverPoints(
            collection, target, context_pairs,
            to_proto_filter(req.filter),
            UInt64(req.limit),
            to_proto_with_payload(req.with_payload),
            to_proto_search_params(req.params),
            req.offset !== nothing ? UInt64(req.offset) : UInt64(0),
            req.using_ !== nothing ? req.using_ : "",
            to_proto_with_vectors(req.with_vector),
            nothing, nothing, UInt64(0), nothing,
        ))
    end
    proto_req = qdrant.DiscoverBatchPoints(
        collection, discover_list, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_DiscoverBatch_Client, proto_req)
    [[from_proto_scored_point(sp) for sp in batch.result] for batch in resp.result]
end
