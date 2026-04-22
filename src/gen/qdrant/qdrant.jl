module qdrant

include("../google/google.jl")

include("json_with_int_pb.jl")
include("qdrant_common_pb.jl")
include("collections_pb.jl")
include("points_pb.jl")
include("snapshots_service_pb.jl")
include("collections_service_pb.jl")
include("points_service_pb.jl")
include("qdrant_pb.jl")

end # module qdrant
