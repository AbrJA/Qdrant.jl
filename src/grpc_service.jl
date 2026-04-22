# ============================================================================
# Service API — gRPC transport
# ============================================================================

function health_check(conn::QdrantConnection{GRPCTransport})
    try
        resp = grpc_request(conn.transport, Qdrant_HealthCheck_Client, qdrant.HealthCheckRequest())
        QdrantResponse(HealthInfo(resp.title, resp.version), "ok", 0.0)
    catch
        QdrantResponse(HealthInfo("qdrant", "unavailable"), "error", 0.0)
    end
end
