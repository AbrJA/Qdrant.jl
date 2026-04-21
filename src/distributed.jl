# ============================================================================
# Distributed / Cluster API
# ============================================================================

"""
    cluster_status(client)

Get cluster status information.
"""
cluster_status(c::QdrantConnection) = execute(HTTP.get, c, "/cluster")
cluster_status() = cluster_status(get_client())
