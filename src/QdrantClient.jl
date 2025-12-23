module QdrantClient

export Client,
    collections, aliases,
    Params, Vectors, HnswConfig,
    Collection, create, delete, exists, details

using HTTP

Base.@kwdef struct Client
    host::String = "http://localhost"
    port::Int    = 6333
    api_key::Union{Nothing, String} = nothing
end

const CLIENT = Ref{Client}()

function set_global_client(client::Client)::Client
    CLIENT[] = client
end

function get_global_client()::Client
    if !isassigned(CLIENT)
        CLIENT[] = Client()
    end
    return CLIENT[]
end

struct Response
    status::Int
    body::Dict{Symbol, Any}
end

function Response(response::HTTP.Response)
    return Response(response.status, JSON.parse(String(response.body); dicttype = Dict{Symbol, Any}))
end

function collections(; client::Client = get_global_client())
    url = "$(client.host):$(client.port)/collections"
    response = HTTP.get(url, status_exception = false)
    return Response(response)
end

function aliases(; client::Client = get_global_client())
    url = "$(client.host):$(client.port)/aliases"
    response = HTTP.get(url, status_exception = false)
    return Response(response)
end

include("collection.jl");
include("params.jl");

end # module QdrantClient
