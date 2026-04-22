# ============================================================================
# gRPC Tests for QdrantClient.jl
# ============================================================================

using Test
using UUIDs
using QdrantClient
using QdrantClient: qdrant, to_proto_point_id, from_proto_point_id,
    to_proto_distance, from_proto_distance,
    julia_value_to_proto, proto_value_to_julia,
    to_proto_payload, from_proto_payload,
    to_proto_vectors, from_proto_vectors,
    to_proto_point, from_proto_scored_point, from_proto_retrieved_point,
    to_proto_filter, to_proto_condition, to_proto_match,
    to_proto_with_payload, to_proto_with_vectors,
    to_proto_search_params, to_proto_points_selector,
    to_proto_vector_params, to_proto_vectors_config,
    to_proto_hnsw_config, to_proto_wal_config, to_proto_optimizers_config,
    to_proto_ordering
using ProtoBuf: OneOf

# ── Helpers ──────────────────────────────────────────────────────────────

const GRPC_CONN = QdrantConnection(GRPCTransport())
const HTTP_CONN = QdrantConnection()
if !@isdefined(unique_name)
    unique_name(prefix="grpc") = string(prefix, "_", replace(string(uuid4()), "-" => ""))
end

function grpc_available(c::QdrantConnection=GRPC_CONN)
    try
        health_check(c)
        true
    catch
        false
    end
end

if !@isdefined(cleanup_collection)
    cleanup_collection(c::QdrantConnection, name) = (try; delete_collection(c, name); catch; end)
end

if !@isdefined(fixture_points)
    fixture_points() = [
        Point(id=1, vector=Float32[1.0, 0.0, 0.0, 0.0],
              payload=Dict{String,Any}("group" => "a", "n" => 1)),
        Point(id=2, vector=Float32[0.9, 0.1, 0.0, 0.0],
              payload=Dict{String,Any}("group" => "a", "n" => 2)),
        Point(id=3, vector=Float32[0.0, 1.0, 0.0, 0.0],
              payload=Dict{String,Any}("group" => "b", "n" => 3)),
    ]
end

# ═══════════════════════════════════════════════════════════════════════════
# Unit Tests — Type Conversions (no server required)
# ═══════════════════════════════════════════════════════════════════════════

@testset "gRPC Unit Tests" begin

    # ── Transport Construction ──────────────────────────────────────────
    @testset "GRPCTransport construction" begin
        t = GRPCTransport()
        @test t.host == "localhost"
        @test t.port == 6334
        @test t.api_key === nothing
        @test t.timeout == 30
        @test t.tls == false
        @test t.max_message_size == 64 * 1024 * 1024

        t2 = GRPCTransport(host="qdrant.example.com", port=6335, tls=true, api_key="secret")
        @test t2.host == "qdrant.example.com"
        @test t2.port == 6335
        @test t2.tls == true
        @test t2.api_key == "secret"
    end

    @testset "is_grpc dispatch" begin
        grpc = QdrantConnection(GRPCTransport())
        http = QdrantConnection()
        @test is_grpc(grpc) == true
        @test is_grpc(http) == false
    end

    # ── PointId Conversion ──────────────────────────────────────────────
    @testset "PointId conversion" begin
        # Int roundtrip
        pid_int = to_proto_point_id(42)
        @test pid_int isa qdrant.PointId
        @test from_proto_point_id(pid_int) == 42

        # Large int
        pid_large = to_proto_point_id(typemax(Int64))
        @test from_proto_point_id(pid_large) == typemax(Int64)

        # UUID roundtrip
        u = uuid4()
        pid_uuid = to_proto_point_id(u)
        @test pid_uuid isa qdrant.PointId
        @test from_proto_point_id(pid_uuid) == u

        # Zero
        pid_zero = to_proto_point_id(0)
        @test from_proto_point_id(pid_zero) == 0
    end

    # ── Distance Conversion ─────────────────────────────────────────────
    @testset "Distance conversion" begin
        for d in (Cosine, Euclid, Dot, Manhattan)
            proto_d = to_proto_distance(d)
            @test from_proto_distance(proto_d) === d
        end
    end

    # ── Value Conversion ────────────────────────────────────────────────
    @testset "Value conversion roundtrips" begin
        # Null
        @test proto_value_to_julia(julia_value_to_proto(nothing)) === nothing

        # Bool
        @test proto_value_to_julia(julia_value_to_proto(true)) === true
        @test proto_value_to_julia(julia_value_to_proto(false)) === false

        # Integer
        @test proto_value_to_julia(julia_value_to_proto(42)) == 42
        @test proto_value_to_julia(julia_value_to_proto(0)) == 0
        @test proto_value_to_julia(julia_value_to_proto(-100)) == -100

        # Float
        v = proto_value_to_julia(julia_value_to_proto(3.14))
        @test v ≈ 3.14

        # String
        @test proto_value_to_julia(julia_value_to_proto("hello")) == "hello"
        @test proto_value_to_julia(julia_value_to_proto("")) == ""

        # List
        @test proto_value_to_julia(julia_value_to_proto([1, 2, 3])) == [1, 2, 3]
        @test proto_value_to_julia(julia_value_to_proto(["a", "b"])) == ["a", "b"]

        # Nested list
        nested = [[1, 2], [3, 4]]
        @test proto_value_to_julia(julia_value_to_proto(nested)) == nested

        # Dict
        d = Dict("a" => 1, "b" => "two")
        result = proto_value_to_julia(julia_value_to_proto(d))
        @test result["a"] == 1
        @test result["b"] == "two"

        # Nested dict
        nd = Dict("outer" => Dict("inner" => 42))
        result = proto_value_to_julia(julia_value_to_proto(nd))
        @test result["outer"]["inner"] == 42
    end

    # ── Payload Conversion ──────────────────────────────────────────────
    @testset "Payload conversion" begin
        payload = Dict{String,Any}("name" => "test", "count" => 5, "tags" => ["a", "b"])
        proto_p = to_proto_payload(payload)
        @test proto_p isa Dict{String,qdrant.Value}
        result = from_proto_payload(proto_p)
        @test result["name"] == "test"
        @test result["count"] == 5
        @test result["tags"] == ["a", "b"]

        # Nothing payload
        @test to_proto_payload(nothing) == Dict{String,qdrant.Value}()
    end

    # ── Vector Conversion ───────────────────────────────────────────────
    @testset "Vector conversion" begin
        # Dense vector
        v = Float32[1.0, 2.0, 3.0, 4.0]
        proto_v = to_proto_vectors(v)
        @test proto_v isa qdrant.Vectors
        @test proto_v.vectors_options.name === :vector

        # NamedVector
        nv = NamedVector(name="image", vector=Float32[1.0, 0.0])
        proto_nv = to_proto_vectors(nv)
        @test proto_nv.vectors_options.name === :vectors

        # Dict of vectors
        dv = Dict("text" => Float32[1.0, 0.0], "image" => Float32[0.0, 1.0])
        proto_dv = to_proto_vectors(dv)
        @test proto_dv.vectors_options.name === :vectors
    end

    # ── Point Conversion ────────────────────────────────────────────────
    @testset "Point conversion" begin
        p = Point(id=42, vector=Float32[1.0, 0.0, 0.0, 0.0],
                  payload=Dict{String,Any}("key" => "val"))
        proto_p = to_proto_point(p)
        @test proto_p isa qdrant.PointStruct
        @test from_proto_point_id(proto_p.id) == 42

        # UUID point
        u = uuid4()
        p2 = Point(id=u, vector=Float32[1.0, 0.0, 0.0, 0.0])
        proto_p2 = to_proto_point(p2)
        @test from_proto_point_id(proto_p2.id) == u
    end

    # ── Filter Conversion ───────────────────────────────────────────────
    @testset "Filter conversion" begin
        # Null filter
        @test to_proto_filter(nothing) === nothing

        # Simple must filter with MatchValue
        f = Filter(must=[FieldCondition(key="color", match=MatchValue(value="red"))])
        proto_f = to_proto_filter(f)
        @test proto_f isa qdrant.Filter
        @test length(proto_f.must) == 1

        # MatchAny with strings
        f2 = Filter(must=[FieldCondition(key="tag", match=MatchAny(any=["a", "b"]))])
        proto_f2 = to_proto_filter(f2)
        @test length(proto_f2.must) == 1

        # MatchAny with integers
        f3 = Filter(must=[FieldCondition(key="n", match=MatchAny(any=[1, 2, 3]))])
        proto_f3 = to_proto_filter(f3)
        @test length(proto_f3.must) == 1

        # MatchText
        f4 = Filter(must=[FieldCondition(key="desc", match=MatchText(text="hello"))])
        proto_f4 = to_proto_filter(f4)
        @test length(proto_f4.must) == 1

        # HasIdCondition
        f5 = Filter(must=[HasIdCondition(has_id=[1, 2])])
        proto_f5 = to_proto_filter(f5)
        @test length(proto_f5.must) == 1

        # IsEmptyCondition
        f6 = Filter(must=[IsEmptyCondition(is_empty=Dict("key" => "field"))])
        proto_f6 = to_proto_filter(f6)
        @test length(proto_f6.must) == 1

        # IsNullCondition
        f7 = Filter(must=[IsNullCondition(is_null=Dict("key" => "field"))])
        proto_f7 = to_proto_filter(f7)
        @test length(proto_f7.must) == 1

        # Combined must + must_not
        f8 = Filter(
            must=[FieldCondition(key="a", match=MatchValue(value="x"))],
            must_not=[FieldCondition(key="b", match=MatchValue(value="y"))]
        )
        proto_f8 = to_proto_filter(f8)
        @test length(proto_f8.must) == 1
        @test length(proto_f8.must_not) == 1

        # RangeCondition
        f9 = Filter(must=[FieldCondition(key="price",
            range=RangeCondition(gte=10.0, lte=100.0))])
        proto_f9 = to_proto_filter(f9)
        @test length(proto_f9.must) == 1
    end

    # ── WithPayload / WithVectors selectors ─────────────────────────────
    @testset "WithPayload/WithVectors selectors" begin
        @test to_proto_with_payload(nothing) === nothing
        @test to_proto_with_payload(true) isa qdrant.WithPayloadSelector
        @test to_proto_with_payload(false) isa qdrant.WithPayloadSelector
        @test to_proto_with_payload(["field1", "field2"]) isa qdrant.WithPayloadSelector

        @test to_proto_with_vectors(nothing) === nothing
        @test to_proto_with_vectors(true) isa qdrant.WithVectorsSelector
        @test to_proto_with_vectors(false) isa qdrant.WithVectorsSelector
        @test to_proto_with_vectors(["vec1"]) isa qdrant.WithVectorsSelector
    end

    # ── SearchParams conversion ─────────────────────────────────────────
    @testset "SearchParams conversion" begin
        @test to_proto_search_params(nothing) === nothing

        sp = SearchParams(hnsw_ef=128, exact=true)
        proto_sp = to_proto_search_params(sp)
        @test proto_sp isa qdrant.SearchParams

        sp2 = SearchParams(quantization=QuantizationSearchParams(
            ignore=true, rescore=true, oversampling=2.0))
        proto_sp2 = to_proto_search_params(sp2)
        @test proto_sp2.quantization !== nothing
    end

    # ── Points Selector ─────────────────────────────────────────────────
    @testset "Points selector conversion" begin
        # IDs selector
        sel_ids = to_proto_points_selector([1, 2, 3])
        @test sel_ids isa qdrant.PointsSelector

        # Single ID
        sel_single = to_proto_points_selector(42)
        @test sel_single isa qdrant.PointsSelector

        # UUID IDs
        u1, u2 = uuid4(), uuid4()
        sel_uuids = to_proto_points_selector([u1, u2])
        @test sel_uuids isa qdrant.PointsSelector

        # Filter selector
        f = Filter(must=[FieldCondition(key="k", match=MatchValue(value="v"))])
        sel_filter = to_proto_points_selector(f)
        @test sel_filter isa qdrant.PointsSelector
    end

    # ── VectorParams / Config conversion ────────────────────────────────
    @testset "VectorParams conversion" begin
        vp = VectorParams(size=128, distance=Cosine)
        proto_vp = to_proto_vector_params(vp)
        @test proto_vp isa qdrant.VectorParams
        @test proto_vp.size == 128

        # With HNSW config
        vp2 = VectorParams(size=64, distance=Dot,
            hnsw_config=HnswConfig(m=32, ef_construct=200))
        proto_vp2 = to_proto_vector_params(vp2)
        @test proto_vp2.size == 64
    end

    @testset "VectorsConfig conversion" begin
        # Single vector config
        vc = to_proto_vectors_config(VectorParams(size=4, distance=Cosine))
        @test vc isa qdrant.VectorsConfig

        # Named vectors config
        named = Dict("text" => VectorParams(size=128, distance=Cosine),
                     "image" => VectorParams(size=256, distance=Dot))
        vc2 = to_proto_vectors_config(named)
        @test vc2 isa qdrant.VectorsConfig
    end

    # ── HNSW / WAL / Optimizers config ──────────────────────────────────
    @testset "Config conversions" begin
        @test to_proto_hnsw_config(nothing) === nothing
        h = HnswConfig(m=16, ef_construct=100)
        @test to_proto_hnsw_config(h) isa qdrant.HnswConfigDiff

        @test to_proto_wal_config(nothing) === nothing
        w = WalConfig(wal_capacity_mb=32)
        @test to_proto_wal_config(w) isa qdrant.WalConfigDiff

        @test to_proto_optimizers_config(nothing) === nothing
        o = OptimizersConfig(default_segment_number=2)
        @test to_proto_optimizers_config(o) isa qdrant.OptimizersConfigDiff
    end

    # ── Ordering conversion ─────────────────────────────────────────────
    @testset "Ordering conversion" begin
        @test to_proto_ordering("weak") isa qdrant.WriteOrdering
        @test to_proto_ordering("medium") isa qdrant.WriteOrdering
        @test to_proto_ordering("strong") isa qdrant.WriteOrdering
    end

end  # gRPC Unit Tests


# ═══════════════════════════════════════════════════════════════════════════
# Integration Tests — require a running Qdrant with gRPC on port 6334
# ═══════════════════════════════════════════════════════════════════════════

@testset "gRPC Integration Tests" begin
    if !grpc_available()
        @warn "Qdrant gRPC not available on port 6334, skipping integration tests"
    else

    # ── Health Check ────────────────────────────────────────────────────
    @testset "Health Check (gRPC)" begin
        result = health_check(GRPC_CONN)
        @test result isa Dict
        @test haskey(result, "title")
    end

    # ── Collection Lifecycle ────────────────────────────────────────────
    @testset "Collection Lifecycle (gRPC)" begin
        name = unique_name("grpc_coll")
        try
            # Create
            config = CollectionConfig(vectors=VectorParams(size=4, distance=Cosine))
            create_collection(GRPC_CONN, name, config)

            # Exists
            exists = collection_exists(GRPC_CONN, name)
            @test exists["exists"] == true

            # List
            result = list_collections(GRPC_CONN)
            collections = result isa Dict ? get(result, "collections", result) : result
            coll_names = [c isa Dict ? get(c, "name", "") : string(c) for c in collections]
            @test name in coll_names

            # Get info
            info = get_collection(GRPC_CONN, name)
            @test info !== nothing

            # Delete
            delete_collection(GRPC_CONN, name)
            @test collection_exists(GRPC_CONN, name)["exists"] == false
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Points CRUD ─────────────────────────────────────────────────────
    @testset "Points CRUD (gRPC)" begin
        name = unique_name("grpc_pts")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

            # Upsert
            pts = fixture_points()
            upsert_points(GRPC_CONN, name, pts)

            # Count
            cnt = count_points(GRPC_CONN, name; exact=true)
            @test cnt isa Dict || cnt isa Integer
            count_val = cnt isa Dict ? get(cnt, "count", 0) : cnt
            @test count_val == 3

            # Get by IDs
            result = get_points(GRPC_CONN, name, [1, 2]; with_payload=true, with_vectors=true)
            @test length(result) == 2

            # Scroll
            scroll_result = scroll_points(GRPC_CONN, name; limit=10, with_payload=true)
            points = scroll_result isa Dict ? get(scroll_result, "points", scroll_result) : scroll_result
            @test length(points) >= 3

            # Delete single point
            delete_points(GRPC_CONN, name, [3])
            cnt2 = count_points(GRPC_CONN, name; exact=true)
            count_val2 = cnt2 isa Dict ? get(cnt2, "count", 0) : cnt2
            @test count_val2 == 2
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Payload Operations ──────────────────────────────────────────────
    @testset "Payload Operations (gRPC)" begin
        name = unique_name("grpc_pay")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            # Set payload
            set_payload(GRPC_CONN, name,
                Dict{String,Any}("color" => "red"), [1])

            # Verify
            pts = get_points(GRPC_CONN, name, [1]; with_payload=true)
            @test length(pts) == 1
            p = first(pts)
            payload = p isa Dict ? get(p, "payload", Dict()) : p
            @test get(payload, "color", nothing) == "red"

            # Delete payload keys
            delete_payload(GRPC_CONN, name, ["color"], [1])
            pts2 = get_points(GRPC_CONN, name, [1]; with_payload=true)
            p2 = first(pts2)
            payload2 = p2 isa Dict ? get(p2, "payload", Dict()) : p2
            @test !haskey(payload2, "color")

            # Clear payload
            clear_payload(GRPC_CONN, name, [2])
            pts3 = get_points(GRPC_CONN, name, [2]; with_payload=true)
            p3 = first(pts3)
            payload3 = p3 isa Dict ? get(p3, "payload", Dict()) : p3
            @test isempty(payload3)
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Search ──────────────────────────────────────────────────────────
    @testset "Search (gRPC)" begin
        name = unique_name("grpc_search")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            # Basic search
            req = SearchRequest(vector=Float32[1.0, 0.0, 0.0, 0.0], limit=3)
            results = search_points(GRPC_CONN, name, req)
            @test length(results) >= 1
            @test first(results)["id"] in [1, 2, 3]

            # Search with filter
            req2 = SearchRequest(
                vector=Float32[1.0, 0.0, 0.0, 0.0],
                limit=3,
                filter=Filter(must=[FieldCondition(key="group", match=MatchValue(value="b"))])
            )
            results2 = search_points(GRPC_CONN, name, req2)
            @test length(results2) >= 1
            @test first(results2)["id"] == 3

            # Search with payload
            req3 = SearchRequest(
                vector=Float32[1.0, 0.0, 0.0, 0.0],
                limit=2,
                with_payload=true
            )
            results3 = search_points(GRPC_CONN, name, req3)
            @test haskey(first(results3), "payload")
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Recommend ───────────────────────────────────────────────────────
    @testset "Recommend (gRPC)" begin
        name = unique_name("grpc_rec")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            req = RecommendRequest(positive=[1], limit=2)
            results = recommend_points(GRPC_CONN, name, req)
            @test length(results) >= 1
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Scroll with Filter ──────────────────────────────────────────────
    @testset "Scroll with Filter (gRPC)" begin
        name = unique_name("grpc_scroll")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            f = Filter(must=[FieldCondition(key="group", match=MatchValue(value="a"))])
            result = scroll_points(GRPC_CONN, name; filter=f, limit=10, with_payload=true)
            points = result isa Dict ? get(result, "points", result) : result
            @test length(points) == 2
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Payload Index ───────────────────────────────────────────────────
    @testset "Payload Index (gRPC)" begin
        name = unique_name("grpc_pidx")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            # Create index (gRPC requires explicit field type; "keyword" maps to proto
            # enum value 0 which proto3 skips encoding, so use "integer" for the "n" field)
            create_payload_index(GRPC_CONN, name, "n"; field_schema="integer")

            # Delete index
            delete_payload_index(GRPC_CONN, name, "n")
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Snapshots ───────────────────────────────────────────────────────
    @testset "Snapshots (gRPC)" begin
        name = unique_name("grpc_snap")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

            # Create snapshot
            snap = create_snapshot(GRPC_CONN, name)
            @test snap !== nothing

            # List snapshots
            snaps = list_snapshots(GRPC_CONN, name)
            @test length(snaps) >= 1

            # Delete snapshot
            snap_name = snaps isa AbstractVector ? first(snaps) : first(snaps)
            snap_name_str = snap_name isa Dict ? snap_name["name"] : string(snap_name)
            delete_snapshot(GRPC_CONN, name, snap_name_str)
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Aliases ─────────────────────────────────────────────────────────
    @testset "Aliases (gRPC)" begin
        name = unique_name("grpc_alias")
        alias = unique_name("alias")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

            # Create alias
            create_alias(GRPC_CONN, alias, name)

            # List aliases
            aliases = list_aliases(GRPC_CONN)
            @test aliases !== nothing

            # List collection aliases
            col_aliases = list_collection_aliases(GRPC_CONN, name)
            @test col_aliases !== nothing

            # Delete alias
            delete_alias(GRPC_CONN, alias)
        finally
            try; delete_alias(GRPC_CONN, alias); catch; end
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Delete by Filter ────────────────────────────────────────────────
    @testset "Delete by Filter (gRPC)" begin
        name = unique_name("grpc_delf")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            # Delete points matching filter
            f = Filter(must=[FieldCondition(key="group", match=MatchValue(value="b"))])
            delete_points(GRPC_CONN, name, f)

            cnt = count_points(GRPC_CONN, name; exact=true)
            count_val = cnt isa Dict ? get(cnt, "count", 0) : cnt
            @test count_val == 2
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ═══════════════════════════════════════════════════════════════════════
    # HTTP ↔ gRPC Parity Tests
    # ═══════════════════════════════════════════════════════════════════════

    @testset "HTTP ↔ gRPC Parity" begin
        name = unique_name("parity")
        try
            # Create via HTTP, verify via gRPC
            create_collection(HTTP_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            @test collection_exists(GRPC_CONN, name)["exists"] == true

            # Upsert via HTTP
            upsert_points(HTTP_CONN, name, fixture_points())

            # Count via gRPC
            cnt = count_points(GRPC_CONN, name; exact=true)
            count_val = cnt isa Dict ? get(cnt, "count", 0) : cnt
            @test count_val == 3

            # Search via both, compare results
            req = SearchRequest(vector=Float32[1.0, 0.0, 0.0, 0.0], limit=3)
            http_results = search_points(HTTP_CONN, name, req)
            grpc_results = search_points(GRPC_CONN, name, req)

            # Both should return same number of results
            @test length(http_results) == length(grpc_results)

            # Top result should be same point
            http_top = http_results[1]
            grpc_top = grpc_results[1]
            http_id = http_top isa AbstractDict ? http_top["id"] : http_top
            grpc_id = grpc_top isa AbstractDict ? grpc_top["id"] : grpc_top
            @test Int(http_id) == Int(grpc_id)

            # Upsert via gRPC, read via HTTP
            extra_pt = Point(id=99, vector=Float32[0.5, 0.5, 0.0, 0.0],
                            payload=Dict{String,Any}("source" => "grpc"))
            upsert_points(GRPC_CONN, name, [extra_pt])

            http_pts = get_points(HTTP_CONN, name, [99]; with_payload=true)
            @test length(http_pts) == 1

            # Delete via gRPC
            delete_collection(GRPC_CONN, name)
            exists_result = collection_exists(HTTP_CONN, name)
            @test exists_result["exists"] == false
        finally
            cleanup_collection(HTTP_CONN, name)
        end
    end

    end  # grpc_available
end  # gRPC Integration Tests
