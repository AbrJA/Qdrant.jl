using HTTP
using JSON

struct Collection
    name::String
    params::Dict{Symbol, Any}
end

function Collection(name::AbstractString; kwargs...)
    return Collection(name, Dict(kwargs))
end

function create(collection::Collection; client::Client = get_global_client(), kwargs...)
    merge!(collection.params, Dict(kwargs))
    url = "$(client.host):$(client.port)/collections/$(collection.name)"
    response = HTTP.put(url, body = JSON.json(collection.params), status_exception = false)
    return Response(response)
end

function delete(collection::Collection; client::Client = get_global_client(), kwargs...)
    url = "$(client.host):$(client.port)/collections/$(collection.name)"
    response = HTTP.delete(url, status_exception = false)
    return Response(response)
end

function exists(collection::Collection; client::Client = get_global_client())
    url = "$(client.host):$(client.port)/collections/$(collection.name)/exists"
    response = HTTP.get(url, status_exception = false)
    return Response(response)
end

function details(collection::Collection; client::Client = get_global_client()) # ¿?
    url = "$(client.host):$(client.port)/collections/$(collection.name)"
    response = HTTP.get(url, status_exception = false)
    return Response(response)
end




function _request(method::Function, collection::Collection, endpoint::String = ""; client::Client = get_global_client())
    base_url = client.host * ":" * string(client.port) * "/collections/" * collection.name
    url = isempty(endpoint) ? base_url : "$base_url/$endpoint"
    response = method(url; status_exception = false)
    return Response(response)
end

delete(collection::Collection; client::Client = get_global_client()) = _request(HTTP.delete, collection; client)

exists(collection::Collection; client::Client = get_global_client()) = _request(HTTP.get, collection, "exists"; client)

details(collection::Collection; client::Client = get_global_client()) = _request(HTTP.get, collection; client)

