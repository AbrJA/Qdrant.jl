using Test
using UUIDs
using HTTP
using JSON
using QdrantClient

const C = Client(host="http://localhost", port=6333)

_name(prefix) = string(prefix, "_", replace(string(uuid4()), "-" => ""))

function _available(c::Client=C)
    try; list_collections(c); true; catch; false; end
end

function _cleanup(c::Client, name)
    try; delete_collection(c, name); catch; end
end

function _cleanup_alias(c::Client, name)
    try; delete_alias(c, name); catch; end
end

function _fixture()
    [
        PointStruct(id=1, vector=Float32[1.0, 0.0, 0.0, 0.0], payload=Dict("group" => "a", "n" => 1)),
        PointStruct(id=2, vector=Float32[0.9, 0.1, 0.0, 0.0], payload=Dict("group" => "a", "n" => 2)),
        PointStruct(id=3, vector=Float32[0.0, 1.0, 0.0, 0.0], payload=Dict("group" => "b", "n" => 3)),
    ]
end

@testset "QdrantClient" begin

    # ── Unit: Type Hierarchy ─────────────────────────────────────────────
    @testset "Type Hierarchy" begin
        @test VectorParams <: AbstractConfig
        @test CollectionConfig <: AbstractConfig
        @test CollectionUpdate <: AbstractConfig
        @test SearchRequest <: AbstractRequest
        @test RecommendRequest <: AbstractRequest
        @test QueryRequest <: AbstractRequest
        @test DiscoverRequest <: AbstractRequest
        @test Filter <: AbstractCondition
        @test FieldCondition <: AbstractCondition
        @test PointStruct <: AbstractQdrantType
    end

    # ── Unit: Distance Enum ──────────────────────────────────────────────
    @testset "Distance Enum" begin
        @test Cosine isa Distance
        @test Euclid isa Distance
        @test Dot isa Distance
        @test Manhattan isa Distance
        @test string(Dot) == "Dot"
        @test string(Cosine) == "Cosine"
    end

    # ── Unit: todict Serialization ───────────────────────────────────────
    @testset "todict Serialization" begin
        vp = VectorParams(size=4, distance=Dot)
        d = todict(vp)
        @test d[:size] == 4
        @test d[:distance] == "Dot"
        @test !haskey(d, :hnsw_config)  # nothing fields stripped

        cfg = CollectionConfig(vectors=vp, on_disk_payload=true)
        dc = todict(cfg)
        @test dc[:vectors][:distance] == "Dot"
        @test dc[:on_disk_payload] === true
        @test !haskey(dc, :sparse_vectors)

        pt = PointStruct(id=1, vector=Float32[1,2,3])
        dp = todict(pt)
        @test dp[:id] == 1
        @test dp[:vector] == Float32[1,2,3]
        @test !haskey(dp, :payload)

        sr = SearchRequest(vector=Float32[1,0,0,0], limit=5, with_payload=true)
        ds = todict(sr)
        @test ds[:limit] == 5
        @test ds[:with_payload] === true
    end

    # ── Unit: Client ─────────────────────────────────────────────────────
    @testset "Client" begin
        c = Client()
        @test c.host == "http://localhost"
        @test c.port == 6333
        @test c.api_key === nothing
        @test c.timeout == 30

        c2 = Client(host="http://example.com", port=8080, api_key="key123")
        @test c2.api_key == "key123"

        set_client!(c2)
        @test get_client().host == "http://example.com"
        set_client!(Client())  # reset

        @test QdrantClient._url(c, "/collections") == "http://localhost:6333/collections"
        @test QdrantClient._url(c, "collections") == "http://localhost:6333/collections"
    end

    # ── Unit: Headers ────────────────────────────────────────────────────
    @testset "Headers" begin
        h = QdrantClient._headers(Client(api_key="secret"))
        hd = Dict(h)
        @test hd["Content-Type"] == "application/json"
        @test hd["api-key"] == "secret"
        @test startswith(hd["User-Agent"], "QdrantClient.jl/")

        h2 = QdrantClient._headers(Client())
        hd2 = Dict(h2)
        @test !haskey(hd2, "api-key")
    end

    # ── Unit: Error ──────────────────────────────────────────────────────
    @testset "Error" begin
        err = QdrantError(404, "Not found")
        @test err.status == 404
        @test err.detail === nothing

        err2 = QdrantError(500, "Fail", Dict(:info => "x"))
        @test err2.detail[:info] == "x"

        buf = IOBuffer()
        showerror(buf, err)
        @test contains(String(take!(buf)), "404")
    end

    # ── Unit: parse_response ─────────────────────────────────────────────
    @testset "parse_response" begin
        empty_resp = HTTP.Response(200, "", body="")
        @test QdrantClient.parse_response(empty_resp) === nothing

        wrapped = HTTP.Response(200, "", body=JSON.json(Dict(
            :status => "ok", :time => 0.01, :result => Dict(:count => 7)
        )))
        @test QdrantClient.parse_response(wrapped)[:count] == 7

        raw = HTTP.Response(200, "", body=JSON.json(Dict(:key => "val")))
        @test QdrantClient.parse_response(raw)[:key] == "val"
    end

    # ── Integration ──────────────────────────────────────────────────────
    @testset "Integration" begin
        if !_available()
            @test_skip "Qdrant not available on localhost:6333"
        else
            @testset "Collection Lifecycle" begin
                coll = _name("jl_coll")
                a1 = coll * "_alias"
                a2 = coll * "_alias2"
                _cleanup_alias(C, a1); _cleanup_alias(C, a2); _cleanup(C, coll)

                @test create_collection(C, coll; vectors=VectorParams(size=4, distance=Dot)) === true

                all = list_collections(C)
                @test any(c[:name] == coll for c in all[:collections])

                @test collection_exists(C, coll)[:exists] === true

                info = get_collection(C, coll)
                @test info[:status] == "green"
                @test info[:config][:params][:vectors][:size] == 4

                @test create_alias(C, a1, coll) === true
                aliases = list_aliases(C)
                @test any(a[:alias_name] == a1 for a in aliases[:aliases])

                ca = list_collection_aliases(C, coll)
                @test any(a[:alias_name] == a1 for a in ca[:aliases])

                @test rename_alias(C, a1, a2) === true
                @test any(a[:alias_name] == a2 for a in list_aliases(C)[:aliases])

                @test delete_alias(C, a2) === true
                @test delete_collection(C, coll) === true
            end

            @testset "Points CRUD" begin
                coll = _name("jl_pts")
                _cleanup(C, coll)
                create_collection(C, coll; vectors=VectorParams(size=4, distance=Dot))
                pts = _fixture()

                res = upsert_points(C, coll, pts; wait=true)
                @test res[:status] == "completed"

                got = get_points(C, coll, [1, 2]; with_vectors=true, with_payload=true)
                @test length(got) == 2
                @test got[1][:id] == 1
                @test got[1][:payload][:group] == "a"
                @test length(got[1][:vector]) == 4

                single = get_points(C, coll, 1; with_payload=true)
                @test length(single) == 1
                @test single[1][:id] == 1

                @test count_points(C, coll; exact=true)[:count] == 3

                @test set_payload(C, coll, Dict("flag" => true), [1, 2])[:status] == "completed"
                @test set_payload(C, coll, Dict("solo" => true), 1)[:status] == "completed"

                after = get_points(C, coll, [1, 2]; with_payload=true)
                @test after[1][:payload][:flag] === true
                @test after[2][:payload][:flag] === true
                @test after[1][:payload][:solo] === true

                @test delete_payload(C, coll, ["flag"], [2])[:status] == "completed"
                @test delete_payload(C, coll, ["solo"], 1)[:status] == "completed"

                p2 = get_points(C, coll, [2]; with_payload=true)
                @test !haskey(p2[1][:payload], :flag)
                p1 = get_points(C, coll, 1; with_payload=true)
                @test !haskey(p1[1][:payload], :solo)

                @test clear_payload(C, coll, 3)[:status] == "completed"
                p3 = get_points(C, coll, [3]; with_payload=true)
                @test isempty(p3[1][:payload])

                @test delete_points(C, coll, 2)[:status] == "completed"
                @test count_points(C, coll; exact=true)[:count] == 2

                _cleanup(C, coll)
            end

            @testset "Search Query Discovery" begin
                coll = _name("jl_search")
                _cleanup(C, coll)
                create_collection(C, coll; vectors=VectorParams(size=4, distance=Dot))
                upsert_points(C, coll, _fixture(); wait=true)

                scrolled = scroll_points(C, coll; limit=10, with_payload=true)
                @test length(scrolled[:points]) == 3

                hits = search_points(C, coll, SearchRequest(vector=Float32[1,0,0,0], limit=2, with_payload=true))
                @test length(hits) == 2
                @test hits[1][:id] == 1

                batch = search_batch(C, coll, [SearchRequest(vector=Float32[1,0,0,0], limit=2)])
                @test length(batch) == 1
                @test length(batch[1]) == 2

                recs = recommend_points(C, coll, RecommendRequest(positive=[1], limit=2, with_payload=true))
                @test length(recs) == 2
                @test recs[1][:id] != 1

                qr = query_points(C, coll, QueryRequest(query=Float32[1,0,0,0], limit=2, with_payload=true))
                @test length(qr[:points]) == 2
                @test qr[:points][1][:id] == 1

                qb = query_batch(C, coll, [QueryRequest(query=Float32[1,0,0,0], limit=2)])
                @test length(qb) == 1
                @test length(qb[1][:points]) == 2

                disc = discover_points(C, coll, DiscoverRequest(target=1, limit=2, with_payload=true))
                @test length(disc) == 2
                @test disc[1][:id] != 1

                _cleanup(C, coll)
            end

            @testset "Snapshots" begin
                coll = _name("jl_snap")
                _cleanup(C, coll)
                create_collection(C, coll; vectors=VectorParams(size=4, distance=Dot))
                upsert_points(C, coll, _fixture(); wait=true)

                snap = create_snapshot(C, coll)
                @test haskey(snap, :name)

                snaps = list_snapshots(C, coll)
                @test length(snaps) >= 1
                @test any(s[:name] == snap[:name] for s in snaps)

                @test delete_snapshot(C, coll, snap[:name]) === true

                _cleanup(C, coll)
            end
        end
    end
end
