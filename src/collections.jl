# ============================================================================
# Collections API
# ============================================================================

collection_path(name::AbstractString) = "/collections/$name"

"""
    list_collections(client) -> Dict

List all collections.
"""
list_collections(c::QdrantConnection) = execute(HTTP.get, c, "/collections")
list_collections() = list_collections(get_client())

"""
    create_collection(client, name, config::CollectionConfig)
    create_collection(client, name; vectors, kwargs...)

Create a new collection.

# Examples
```julia
create_collection(client, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
create_collection(client, "demo"; vectors=VectorParams(size=4, distance=Dot))
```
"""
function create_collection(c::QdrantConnection, name::AbstractString, config::CollectionConfig)
    execute(HTTP.put, c, collection_path(name), config)
end
create_collection(name::AbstractString, config::CollectionConfig) =
    create_collection(get_client(), name, config)
create_collection(c::QdrantConnection, name::AbstractString; kwargs...) =
    create_collection(c, name, CollectionConfig(; kwargs...))
create_collection(name::AbstractString; kwargs...) =
    create_collection(get_client(), name; kwargs...)

"""
    delete_collection(client, name) -> Bool

Delete a collection.
"""
delete_collection(c::QdrantConnection, name::AbstractString) =
    execute(HTTP.delete, c, collection_path(name))
delete_collection(name::AbstractString) = delete_collection(get_client(), name)

"""
    collection_exists(client, name) -> Dict

Check if a collection exists.
"""
function collection_exists(c::QdrantConnection, name::AbstractString)
    execute(HTTP.get, c, collection_path(name) * "/exists")
end
collection_exists(name::AbstractString) = collection_exists(get_client(), name)

"""
    get_collection(client, name) -> Dict

Get detailed collection information.
"""
get_collection(c::QdrantConnection, name::AbstractString) =
    execute(HTTP.get, c, collection_path(name))
get_collection(name::AbstractString) = get_collection(get_client(), name)

"""
    update_collection(client, name, config::CollectionUpdate)
    update_collection(client, name; kwargs...)

Update collection parameters.
"""
function update_collection(c::QdrantConnection, name::AbstractString, config::CollectionUpdate)
    execute(HTTP.patch, c, collection_path(name), config)
end
update_collection(name::AbstractString, config::CollectionUpdate) =
    update_collection(get_client(), name, config)
update_collection(c::QdrantConnection, name::AbstractString; kwargs...) =
    update_collection(c, name, CollectionUpdate(; kwargs...))
update_collection(name::AbstractString; kwargs...) =
    update_collection(get_client(), name; kwargs...)

# ── Aliases ──────────────────────────────────────────────────────────────

alias_action_body(action::AbstractString, payload::AbstractDict) =
    Dict{String,Any}("actions" => [Dict(action => Dict(payload))])

"""
    list_aliases(client) -> Dict

List all aliases across collections.
"""
list_aliases(c::QdrantConnection) = execute(HTTP.get, c, "/aliases")
list_aliases() = list_aliases(get_client())

"""
    list_collection_aliases(client, collection) -> Dict

List aliases for a specific collection.
"""
list_collection_aliases(c::QdrantConnection, name::AbstractString) =
    execute(HTTP.get, c, collection_path(name) * "/aliases")
list_collection_aliases(name::AbstractString) =
    list_collection_aliases(get_client(), name)

"""
    create_alias(client, alias, collection) -> Bool
"""
function create_alias(c::QdrantConnection, alias::AbstractString, collection::AbstractString)
    body = alias_action_body("create_alias", Dict("collection_name" => collection, "alias_name" => alias))
    execute(HTTP.post, c, "/collections/aliases", body)
end
create_alias(alias::AbstractString, collection::AbstractString) =
    create_alias(get_client(), alias, collection)

"""
    delete_alias(client, alias) -> Bool
"""
function delete_alias(c::QdrantConnection, alias::AbstractString)
    body = alias_action_body("delete_alias", Dict("alias_name" => alias))
    execute(HTTP.post, c, "/collections/aliases", body)
end
delete_alias(alias::AbstractString) = delete_alias(get_client(), alias)

"""
    rename_alias(client, old, new) -> Bool
"""
function rename_alias(c::QdrantConnection, old::AbstractString, new_name::AbstractString)
    body = alias_action_body("rename_alias", Dict("old_alias_name" => old, "new_alias_name" => new_name))
    execute(HTTP.post, c, "/collections/aliases", body)
end
rename_alias(old::AbstractString, new_name::AbstractString) =
    rename_alias(get_client(), old, new_name)
