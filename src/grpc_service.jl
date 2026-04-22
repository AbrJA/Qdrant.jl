# ============================================================================
# gRPC Service API (Health Check) — dispatch on GRPCTransport
# ============================================================================

function health_check(c::QdrantConnection, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    try
        resp = grpc_request(transport, Qdrant_HealthCheck_Client, qdrant.HealthCheckRequest())
        Dict{String,Any}(
            "status" => "healthy",
            "title" => resp.title,
            "version" => resp.version,
            "commit" => resp.commit,
        )
    catch e
        Dict{String,Any}("status" => "unhealthy", "error" => string(e))
    end
end
