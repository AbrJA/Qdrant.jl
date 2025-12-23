using QdrantClient

collections()
aliases()

params = Vectors()
hnsw_config = HnswConfig(m = 2, ef_construct = 10, full_scan_threshold = 100, max_indexing_threads = 4, on_disk = false, payload_m = 16)
params = Params(vectors = Vectors(size = 128, distance = :Cosine), hnsw_config = hnsw_config)
params = Params(vectors = Vectors(size = 128, distance = :Cosine, hnsw_config = hnsw_config))

collection = Collection("my_collection", params)

# exists(collection)
# details(collection)

delete(collection)
create(collection)


