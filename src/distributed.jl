# ============================================================================
# Distributed / Cluster API
# ============================================================================

"""
    cluster_status(client)

Get cluster status information.
"""
cluster_status(c::Client) = _rp(HTTP.get, c, "/cluster")
cluster_status() = cluster_status(get_client())
