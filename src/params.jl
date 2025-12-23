macro param(name, block)
    fields = [f for f in block.args if f isa Expr && f.head == :(::)]
    kwargs = [
        Expr(:kw, Expr(:(::), f.args[1], :(Union{$(f.args[2]), Nothing})), nothing)
        for f in fields
    ]
    dictpairs = [:( $(QuoteNode(f.args[1])) => $(f.args[1]) ) for f in fields]
    return quote
        function $(esc(name))(; $(kwargs...), kwargs...)
            dict = Dict($(dictpairs...))
            merge!(dict, Dict(kwargs))
            filter(!isnothing ∘ last, dict)
        end
    end
end

@param Params begin


end

@param Vectors begin
    size::Int
    distance::Symbol
end

@param HnswConfig begin
    m::Int
    ef_construct::Int
    full_scan_threshold::Int
    max_indexing_threads::Int
    on_disk::Bool
    payload_m::Int
end

@param WalConfig begin
    wal_capacity_mb::Int
    wal_segments_ahead::Int
end

@param OptimizersConfig begin
    delete_threshold::Float32
    vacuum_min_vector_number::Int
    default_segment_number::Int
    max_segment_size::Int
    indexing_threshold::Int
    flush_interval_sec::UInt
    max_optimization_threads::Int
end
