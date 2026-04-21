"""
    QdrantError <: Exception

Error from the Qdrant API.

# Fields
- `status::Int`: HTTP status code (0 for non-HTTP errors)
- `message::String`: Human-readable error description
- `detail::Any`: Parsed error details from the API response
"""
struct QdrantError <: Exception
    status::Int
    message::String
    detail::Any
end

QdrantError(status::Integer, message::AbstractString) = QdrantError(Int(status), String(message), nothing)

function Base.showerror(io::IO, err::QdrantError)
    print(io, "QdrantError")
    err.status != 0 && print(io, " [HTTP ", err.status, "]")
    print(io, ": ", err.message)
    err.detail !== nothing && print(io, "\n  Detail: ", err.detail)
end
