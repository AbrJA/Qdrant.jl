# ============================================================================
# Service API — HTTP transport
# ============================================================================

"""
    health_check(conn) -> QdrantResponse{HealthInfo}

Check server health.
"""
function health_check(conn::QdrantConnection{HTTPTransport}=get_client())
    try
        resp = http_request(HTTP.get, conn, "/")
        raw, status, time = _unwrap(resp)
        info = raw isa AbstractDict ?
            HealthInfo(String(get(raw, "title", "qdrant")),
                       String(get(raw, "version", "unknown"))) :
            HealthInfo("qdrant", "unknown")
        QdrantResponse(info, status, time)
    catch
        QdrantResponse(HealthInfo("qdrant", "unavailable"), "error", 0.0)
    end
end

"""
    get_version(conn) -> QdrantResponse{HealthInfo}

Get Qdrant server version and title.
"""
function get_version(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/")
    raw, status, time = _unwrap(resp)
    info = raw isa AbstractDict ?
        HealthInfo(String(get(raw, "title", "qdrant")),
                   String(get(raw, "version", "unknown"))) :
        HealthInfo("qdrant", "unknown")
    QdrantResponse(info, status, time)
end

"""
    get_metrics(conn) -> QdrantResponse{String}

Retrieve Prometheus-format metrics (plain text response).
"""
function get_metrics(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/metrics")
    QdrantResponse(String(resp.body), "", 0.0)  # plain text, no status field
end

"""
    get_telemetry(conn) -> QdrantResponse{Dict{String,Any}}

Retrieve telemetry data.
"""
function get_telemetry(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/telemetry")
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end

# ── Kubernetes Health Probes ─────────────────────────────────────────────

"""
    healthz(conn) -> QdrantResponse{String}

Kubernetes health check endpoint (plain text response).
"""
function healthz(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/healthz")
    QdrantResponse(String(resp.body), "", 0.0)  # plain text, no status field
end

"""
    livez(conn) -> QdrantResponse{String}

Kubernetes liveness probe (plain text response).
"""
function livez(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/livez")
    QdrantResponse(String(resp.body), "", 0.0)  # plain text, no status field
end

"""
    readyz(conn) -> QdrantResponse{String}

Kubernetes readiness probe (plain text response).
"""
function readyz(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/readyz")
    QdrantResponse(String(resp.body), "", 0.0)  # plain text, no status field
end

# ── Issues ───────────────────────────────────────────────────────────────

"""
    get_issues(conn) -> QdrantResponse{Dict{String,Any}}

Get performance issues and configuration suggestions.
"""
function get_issues(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/issues")
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end

"""
    clear_issues(conn) -> QdrantResponse{Bool}

Clear all reported issues.
"""
function clear_issues(conn::QdrantConnection{HTTPTransport}=get_client())
    parse_bool(http_request(HTTP.delete, conn, "/issues"))
end
