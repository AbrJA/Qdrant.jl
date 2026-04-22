# ============================================================================
# gRPC Search / Recommend / Query API — dispatch on GRPCTransport
# ============================================================================

# ── Search ───────────────────────────────────────────────────────────────

function search_points(c::QdrantConnection, collection::AbstractString,
                       req::SearchRequest, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    # Build vector data
    vector_data = Float32[]
    vector_name = nothing
    if req.vector isa AbstractVector
        vector_data = Float32.(req.vector)
    elseif req.vector isa NamedVector
        vector_data = Float32.(req.vector.vector)
        vector_name = req.vector.name
    elseif req.vector isa String
        vector_name = req.vector
    end

    proto_req = qdrant.SearchPoints(
        collection,                                    # collection_name
        vector_data,                                   # vector (deprecated but needed)
        to_proto_filter(req.filter),                   # filter
        UInt64(req.limit),                             # limit
        to_proto_with_payload(req.with_payload),       # with_payload
        to_proto_search_params(req.params),            # params
        req.score_threshold !== nothing ? Float32(req.score_threshold) : Float32(0),
        req.offset !== nothing ? UInt64(req.offset) : UInt64(0),
        vector_name !== nothing ? vector_name : "",    # vector_name
        to_proto_with_vectors(req.with_vector),        # with_vectors
        nothing,                                       # read_consistency
        UInt64(0),                                     # timeout
        nothing,                                       # shard_key_selector
        nothing,                                       # sparse_indices
    )
    resp = grpc_request(transport, Points_Search_Client, proto_req)
    [from_proto_scored_point(sp) for sp in resp.result]
end

# ── Search Batch ─────────────────────────────────────────────────────────

function search_batch(c::QdrantConnection, collection::AbstractString,
                      requests::AbstractVector{SearchRequest}, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    search_points_list = qdrant.SearchPoints[]
    for req in requests
        vector_data = Float32[]
        vector_name = nothing
        if req.vector isa AbstractVector
            vector_data = Float32.(req.vector)
        elseif req.vector isa NamedVector
            vector_data = Float32.(req.vector.vector)
            vector_name = req.vector.name
        end
        push!(search_points_list, qdrant.SearchPoints(
            collection, vector_data,
            to_proto_filter(req.filter),
            UInt64(req.limit),
            to_proto_with_payload(req.with_payload),
            to_proto_search_params(req.params),
            req.score_threshold !== nothing ? Float32(req.score_threshold) : Float32(0),
            req.offset !== nothing ? UInt64(req.offset) : UInt64(0),
            vector_name !== nothing ? vector_name : "",
            to_proto_with_vectors(req.with_vector),
            nothing, UInt64(0), nothing, nothing,
        ))
    end
    proto_req = qdrant.SearchBatchPoints(
        collection, search_points_list, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_SearchBatch_Client, proto_req)
    [[from_proto_scored_point(sp) for sp in batch.result] for batch in resp.result]
end

# ── Search Groups ────────────────────────────────────────────────────────

function search_groups(c::QdrantConnection, collection::AbstractString,
                       req::AbstractDict, ::Val{:grpc}; group_size::Int=1)
    transport = c.transport::GRPCTransport
    vector_data = Float32[]
    if haskey(req, "vector") && req["vector"] isa AbstractVector
        vector_data = Float32.(req["vector"])
    end
    proto_req = qdrant.SearchPointGroups(
        collection,
        vector_data,
        nothing,  # filter
        haskey(req, "limit") ? UInt32(req["limit"]) : UInt32(10),
        nothing,  # with_payload
        nothing,  # params
        Float32(0),  # score_threshold
        haskey(req, "vector_name") ? req["vector_name"] : "",
        nothing,  # with_vectors
        haskey(req, "group_by") ? req["group_by"] : "",
        UInt32(group_size),
        nothing,  # read_consistency
        nothing,  # with_lookup
        UInt64(0),  # timeout
        nothing,  # shard_key_selector
        nothing,  # sparse_indices
    )
    resp = grpc_request(transport, Points_SearchGroups_Client, proto_req)
    _groups_result_to_dict(resp.result)
end

function _groups_result_to_dict(gr::Nothing)
    Dict{String,Any}("groups" => Any[])
end
function _groups_result_to_dict(gr::qdrant.GroupsResult)
    groups = Any[]
    for g in gr.groups
        group = Dict{String,Any}(
            "hits" => [from_proto_scored_point(sp) for sp in g.hits],
        )
        if g.id !== nothing
            gid = g.id.kind
            group["id"] = gid.name === :unsigned_value ? Int(gid.value) :
                          gid.name === :integer_value ? Int(gid.value) :
                          gid.value
        end
        push!(groups, group)
    end
    Dict{String,Any}("groups" => groups)
end

# ── Recommend ────────────────────────────────────────────────────────────

function recommend_points(c::QdrantConnection, collection::AbstractString,
                          req::RecommendRequest, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    positive_ids = qdrant.PointId[]
    negative_ids = qdrant.PointId[]
    if req.positive !== nothing
        for p in req.positive
            push!(positive_ids, to_proto_point_id(p isa PointId ? p : Int(p)))
        end
    end
    if req.negative !== nothing
        for n in req.negative
            push!(negative_ids, to_proto_point_id(n isa PointId ? n : Int(n)))
        end
    end
    proto_req = qdrant.RecommendPoints(
        collection,                                    # collection_name
        positive_ids,                                  # positive
        negative_ids,                                  # negative
        to_proto_filter(req.filter),                   # filter
        UInt64(req.limit),                             # limit
        to_proto_with_payload(req.with_payload),       # with_payload
        to_proto_search_params(req.params),            # params
        req.score_threshold !== nothing ? Float32(req.score_threshold) : Float32(0),
        req.offset !== nothing ? UInt64(req.offset) : UInt64(0),
        req.using_ !== nothing ? req.using_ : "",      # using
        to_proto_with_vectors(req.with_vector),        # with_vectors
        nothing,                                       # lookup_from
        nothing,                                       # read_consistency
        qdrant.RecommendStrategy.AverageVector,        # strategy
        qdrant.var"#Vector"[],                         # positive_vectors
        qdrant.var"#Vector"[],                         # negative_vectors
        UInt64(0),                                     # timeout
        nothing,                                       # shard_key_selector
    )
    resp = grpc_request(transport, Points_Recommend_Client, proto_req)
    [from_proto_scored_point(sp) for sp in resp.result]
end

# ── Recommend Batch ──────────────────────────────────────────────────────

function recommend_batch(c::QdrantConnection, collection::AbstractString,
                         requests::AbstractVector{RecommendRequest}, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    recommend_list = qdrant.RecommendPoints[]
    for req in requests
        positive_ids = qdrant.PointId[]
        negative_ids = qdrant.PointId[]
        if req.positive !== nothing
            for p in req.positive
                push!(positive_ids, to_proto_point_id(p isa PointId ? p : Int(p)))
            end
        end
        if req.negative !== nothing
            for n in req.negative
                push!(negative_ids, to_proto_point_id(n isa PointId ? n : Int(n)))
            end
        end
        push!(recommend_list, qdrant.RecommendPoints(
            collection, positive_ids, negative_ids,
            to_proto_filter(req.filter),
            UInt64(req.limit),
            to_proto_with_payload(req.with_payload),
            to_proto_search_params(req.params),
            req.score_threshold !== nothing ? Float32(req.score_threshold) : Float32(0),
            req.offset !== nothing ? UInt64(req.offset) : UInt64(0),
            req.using_ !== nothing ? req.using_ : "",
            to_proto_with_vectors(req.with_vector),
            nothing, nothing, qdrant.RecommendStrategy.AverageVector,
            qdrant.var"#Vector"[], qdrant.var"#Vector"[],
            UInt64(0), nothing,
        ))
    end
    proto_req = qdrant.RecommendBatchPoints(
        collection, recommend_list, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_RecommendBatch_Client, proto_req)
    [[from_proto_scored_point(sp) for sp in batch.result] for batch in resp.result]
end

# ── Query Points ─────────────────────────────────────────────────────────

function query_points(c::QdrantConnection, collection::AbstractString,
                      req::QueryRequest, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    # Build query from the request
    query = nothing
    if req.query !== nothing
        if req.query isa AbstractVector{<:AbstractFloat}
            dense = qdrant.DenseVector(Float32.(req.query))
            vi = qdrant.VectorInput(OneOf(:dense, dense))
            query = qdrant.Query(OneOf(:nearest, vi))
        elseif req.query isa String
            # Order by field
            query = qdrant.Query(OneOf(:order_by, qdrant.OrderBy(req.query, qdrant.Direction.Asc, nothing)))
        end
    end

    proto_req = qdrant.QueryPoints(
        collection,                                    # collection_name
        qdrant.PrefetchQuery[],                        # prefetch
        query,                                         # query
        req.using_ !== nothing ? req.using_ : "",      # using
        to_proto_filter(req.filter),                   # filter
        to_proto_search_params(req.params),            # params
        req.score_threshold !== nothing ? Float32(req.score_threshold) : Float32(0),
        req.limit !== nothing ? UInt64(req.limit) : UInt64(10),
        req.offset !== nothing ? UInt64(req.offset) : UInt64(0),
        to_proto_with_vectors(req.with_vector),        # with_vectors
        to_proto_with_payload(req.with_payload),       # with_payload
        nothing,                                       # read_consistency
        nothing,                                       # shard_key_selector
        nothing,                                       # lookup_from
        UInt64(0),                                     # timeout
    )
    resp = grpc_request(transport, Points_Query_Client, proto_req)
    [from_proto_scored_point(sp) for sp in resp.result]
end

# ── Query Batch ──────────────────────────────────────────────────────────

function query_batch(c::QdrantConnection, collection::AbstractString,
                     requests::AbstractVector{QueryRequest}, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    query_list = qdrant.QueryPoints[]
    for req in requests
        query = nothing
        if req.query !== nothing && req.query isa AbstractVector{<:AbstractFloat}
            dense = qdrant.DenseVector(Float32.(req.query))
            vi = qdrant.VectorInput(OneOf(:dense, dense))
            query = qdrant.Query(OneOf(:nearest, vi))
        end
        push!(query_list, qdrant.QueryPoints(
            collection,
            qdrant.PrefetchQuery[],
            query,
            req.using_ !== nothing ? req.using_ : "",
            to_proto_filter(req.filter),
            to_proto_search_params(req.params),
            req.score_threshold !== nothing ? Float32(req.score_threshold) : Float32(0),
            req.limit !== nothing ? UInt64(req.limit) : UInt64(10),
            req.offset !== nothing ? UInt64(req.offset) : UInt64(0),
            to_proto_with_vectors(req.with_vector),
            to_proto_with_payload(req.with_payload),
            nothing, nothing, nothing, UInt64(0),
        ))
    end
    proto_req = qdrant.QueryBatchPoints(
        collection, query_list, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_QueryBatch_Client, proto_req)
    [[from_proto_scored_point(sp) for sp in batch.result] for batch in resp.result]
end

# ── Query Groups ─────────────────────────────────────────────────────────

function query_groups(c::QdrantConnection, collection::AbstractString,
                      req::AbstractDict, ::Val{:grpc}; group_size::Int=1)
    transport = c.transport::GRPCTransport
    query = nothing
    if haskey(req, "query") && req["query"] isa AbstractVector{<:AbstractFloat}
        dense = qdrant.DenseVector(Float32.(req["query"]))
        vi = qdrant.VectorInput(OneOf(:dense, dense))
        query = qdrant.Query(OneOf(:nearest, vi))
    end
    proto_req = qdrant.QueryPointGroups(
        collection,
        qdrant.PrefetchQuery[],
        query,
        haskey(req, "using") ? req["using"] : "",
        nothing,  # filter
        nothing,  # params
        Float32(0),  # score_threshold
        nothing,  # with_payload
        nothing,  # with_vectors
        nothing,  # lookup_from
        haskey(req, "limit") ? UInt64(req["limit"]) : UInt64(3),
        haskey(req, "group_size") ? UInt64(req["group_size"]) : UInt64(group_size),
        haskey(req, "group_by") ? req["group_by"] : "",
        nothing,  # read_consistency
        nothing,  # with_lookup
        UInt64(0),  # timeout
        nothing,  # shard_key_selector
    )
    resp = grpc_request(transport, Points_QueryGroups_Client, proto_req)
    _groups_result_to_dict(resp.result)
end
