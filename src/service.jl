# ============================================================================
# Service API (Health, Metrics, Telemetry)
# ============================================================================

"""
    health_check(client)

Check server health by probing the collections endpoint.
Returns a Dict with `:status` ("healthy" or "unhealthy").
"""
function health_check(c::Client=get_client())
    try
        resp = _rp(HTTP.get, c, "/collections")
        Dict{String,Any}("status" => "healthy", "response" => resp)
    catch e
        Dict{String,Any}("status" => "unhealthy", "error" => string(e))
    end
end

"""
    get_metrics(client)

Retrieve Prometheus-format metrics from the server.
"""
get_metrics(c::Client=get_client()) = parse_response(request(HTTP.get, c, "/metrics"))

"""
    get_telemetry(client)

Retrieve telemetry data from the server.
"""
get_telemetry(c::Client=get_client()) = _rp(HTTP.get, c, "/telemetry")
