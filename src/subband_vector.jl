"""
    SubbandLayout(sizes, signal_size)

Where each subband of a [`SubbandVector`](@ref) lies in its flat storage:
subband `i` has size `sizes[i]` and occupies the next `prod(sizes[i])`
entries after subband `i - 1`.  `signal_size` is the size of the data the
coefficients describe.  Layouts are compared by value.
"""
struct SubbandLayout{N}
    sizes::Vector{NTuple{N, Int}}
    ranges::Vector{UnitRange{Int}}
    signal_size::NTuple{N, Int}
    function SubbandLayout{N}(sizes, signal_size) where {N}
        sizes = collect(NTuple{N, Int}, sizes)
        isempty(sizes) && throw(ArgumentError("a layout needs at least one subband"))
        all(s -> all(>=(0), s), sizes) || throw(ArgumentError("subband sizes must be nonnegative, got $(sizes)"))
        ranges = Vector{UnitRange{Int}}(undef, length(sizes))
        last = 0
        for i in eachindex(sizes, ranges)
            ranges[i] = (last + 1):(last + prod(sizes[i]))
            last = ranges[i][end]
        end
        return new{N}(sizes, ranges, signal_size)
    end
end

SubbandLayout(sizes::AbstractVector{NTuple{N, Int}}, signal_size::Dims{N}) where {N} =
    SubbandLayout{N}(sizes, signal_size)

Base.length(l::SubbandLayout) = isempty(l.ranges) ? 0 : l.ranges[end][end]
Base.:(==)(a::SubbandLayout, b::SubbandLayout) = a.sizes == b.sizes && a.signal_size == b.signal_size
Base.hash(l::SubbandLayout, h::UInt) = hash(l.signal_size, hash(l.sizes, hash(:SubbandLayout, h)))

nsubbands(l::SubbandLayout) = length(l.sizes)

"""
    SubbandVector(data::AbstractVector, layout::SubbandLayout)

Coefficients made of subbands of different sizes, stored one after another in
the single vector `data` (a host `Vector` or a device vector) and presented as
an `AbstractVector` of all coefficients.  [`subband(c, i)`](@ref subband) is a
reshaped view of subband `i`.

Broadcasting, `similar`, `copyto!`, `fill!`, `==`, `isapprox`, `mapreduce`
(`sum`, `maximum`, ...) and `LinearAlgebra.dot`/`norm`/`axpy!`/`axpby!`/
`rmul!`/`lmul!` act on `data` directly, so they need no scalar indexing on
a device and keep the layout.  Operands of one operation must share a layout.
`Adapt.adapt` moves the storage (a method defined once Adapt is loaded, as
every GPU array package does).

```jldoctest
julia> using MultiscaleTransformsBase

julia> layout = SubbandLayout([(2, 2), (4, 4)], (4, 4));

julia> c = SubbandVector(collect(1.0:20.0), layout);

julia> subband(c, 1)
2×2 reshape(view(::Vector{Float64}, 1:4), 2, 2) with eltype Float64:
 1.0  3.0
 2.0  4.0

julia> d = 2 .* c .+ 1;

julia> d isa SubbandVector && subband(d, 1)[1] == 3.0
true
```
"""
struct SubbandVector{T, V <: AbstractVector{T}, N} <: AbstractVector{T}
    data::V
    layout::SubbandLayout{N}
    function SubbandVector{T, V, N}(data, layout) where {T, V <: AbstractVector{T}, N}
        length(data) == length(layout) ||
            throw(DimensionMismatch("the layout holds $(length(layout)) coefficients, the data $(length(data))"))
        return new{T, V, N}(data, layout)
    end
end

SubbandVector(data::AbstractVector{T}, layout::SubbandLayout{N}) where {T, N} =
    SubbandVector{T, typeof(data), N}(data, layout)

"""
    SubbandVector{T}(undef, layout, like::AbstractArray)

Uninitialised coefficients of element type `T` with `layout`, stored in an
array of the kind of `like` (host or device).
"""
SubbandVector{T}(::UndefInitializer, layout::SubbandLayout, like::AbstractArray) where {T} =
    SubbandVector(similar(like, T, length(layout)), layout)

Base.parent(c::SubbandVector) = c.data
Base.size(c::SubbandVector) = size(c.data)
Base.IndexStyle(::Type{<:SubbandVector}) = IndexLinear()
Base.@propagate_inbounds Base.getindex(c::SubbandVector, i::Int) = c.data[i]
Base.@propagate_inbounds Base.setindex!(c::SubbandVector, v, i::Int) = (c.data[i] = v; c)
Base.dataids(c::SubbandVector) = Base.dataids(c.data)
Base.unaliascopy(c::SubbandVector) = copy(c)

nsubbands(c::SubbandVector) = nsubbands(c.layout)
subband(c::SubbandVector, i::Integer) = reshape(view(c.data, c.layout.ranges[i]), c.layout.sizes[i])
# The default `synthesize` reads the data size from a SubbandVector's layout;
# `signal_size` itself gets no method here, so that a package's
# `signal_size(::MyTransform, ::AbstractArray)` cannot be ambiguous with it.
_signal_size(::AbstractMultiscaleTransform, c::SubbandVector) = c.layout.signal_size
_signal_size(t::AbstractMultiscaleTransform, c) = signal_size(t, c)

Base.similar(c::SubbandVector, ::Type{S}) where {S} = SubbandVector(similar(c.data, S), c.layout)
Base.similar(c::SubbandVector, ::Type{S}, dims::Dims) where {S} = similar(c.data, S, dims)
Base.copy(c::SubbandVector) = SubbandVector(copy(c.data), c.layout)
Base.Array(c::SubbandVector) = Array(c.data)
Base.Vector(c::SubbandVector) = Vector(c.data)
Base.collect(c::SubbandVector) = collect(c.data)
Base.zero(c::SubbandVector) = fill!(similar(c), zero(eltype(c)))

function _same_layout(a::SubbandVector, b::SubbandVector)
    a.layout === b.layout || a.layout == b.layout ||
        throw(DimensionMismatch("the coefficients have different subband layouts"))
    return nothing
end

function Base.copyto!(dest::SubbandVector, src::SubbandVector)
    _same_layout(dest, src)
    copyto!(dest.data, src.data)
    return dest
end
Base.fill!(c::SubbandVector, v) = (fill!(c.data, v); c)

Base.:(==)(a::SubbandVector, b::SubbandVector) = a.layout == b.layout && a.data == b.data
Base.isapprox(a::SubbandVector, b::SubbandVector; kwargs...) =
    a.layout == b.layout && isapprox(a.data, b.data; kwargs...)
Base.mapreduce(f, op, c::SubbandVector; kwargs...) = mapreduce(f, op, c.data; kwargs...)

LinearAlgebra.dot(a::SubbandVector, b::SubbandVector) = (_same_layout(a, b); LinearAlgebra.dot(a.data, b.data))
LinearAlgebra.norm(c::SubbandVector, p::Real = 2) = LinearAlgebra.norm(c.data, p)
function LinearAlgebra.axpy!(α::Number, x::SubbandVector, y::SubbandVector)
    _same_layout(x, y)
    LinearAlgebra.axpy!(α, x.data, y.data)
    return y
end
function LinearAlgebra.axpby!(α::Number, x::SubbandVector, β::Number, y::SubbandVector)
    _same_layout(x, y)
    LinearAlgebra.axpby!(α, x.data, β, y.data)
    return y
end
LinearAlgebra.rmul!(c::SubbandVector, α::Number) = (LinearAlgebra.rmul!(c.data, α); c)
LinearAlgebra.lmul!(α::Number, c::SubbandVector) = (LinearAlgebra.lmul!(α, c.data); c)

function Base.summary(io::IO, c::SubbandVector)
    n = nsubbands(c)
    return print(io, length(c), "-element SubbandVector{", eltype(c), "} with ", n, n == 1 ? " subband" : " subbands", " of ", typeof(c.data))
end
Base.show(io::IO, ::MIME"text/plain", c::SubbandVector) = summary(io, c)

# ── Broadcasting ─────────────────────────────────────────────────────────────
# A broadcast over SubbandVectors runs on their storage vectors, in the
# storage's own style (so a device kernel, never scalar indexing), and wraps
# the result in the operands' layout.

struct SubbandStyle{S <: Broadcast.BroadcastStyle} <: Broadcast.AbstractArrayStyle{1} end
SubbandStyle(::S) where {S <: Broadcast.BroadcastStyle} = SubbandStyle{S}()
SubbandStyle{S}(::Val{1}) where {S} = SubbandStyle{S}()
SubbandStyle{S}(::Val{N}) where {S, N} = Broadcast.DefaultArrayStyle{N}()

Base.BroadcastStyle(::Type{<:SubbandVector{T, V}}) where {T, V} = SubbandStyle(Base.BroadcastStyle(V))
Base.BroadcastStyle(::SubbandStyle{A}, ::SubbandStyle{B}) where {A, B} =
    SubbandStyle(Base.BroadcastStyle(A(), B()))

_storage(c::SubbandVector) = c.data
_storage(bc::Broadcast.Broadcasted) = Broadcast.broadcasted(bc.f, map(_storage, bc.args)...)
_storage(x) = x

# The first SubbandVector among a broadcast's operands, at any depth.
_find_subbands(bc::Broadcast.Broadcasted) = _find_in(bc.args)
_find_subbands(c::SubbandVector) = c
_find_subbands(_) = nothing
_find_in(::Tuple{}) = nothing
function _find_in(args::Tuple)
    c = _find_subbands(first(args))
    return c === nothing ? _find_in(Base.tail(args)) : c
end

_check_layouts(layout, bc::Broadcast.Broadcasted) = foreach(a -> _check_layouts(layout, a), bc.args)
_check_layouts(layout, c::SubbandVector) =
    c.layout === layout || c.layout == layout ||
    throw(DimensionMismatch("the coefficients have different subband layouts"))
_check_layouts(layout, _) = nothing

function Base.similar(bc::Broadcast.Broadcasted{<:SubbandStyle}, ::Type{T}) where {T}
    c = _find_subbands(bc)
    return SubbandVector(similar(c.data, T), c.layout)
end

function Base.copyto!(dest::SubbandVector, bc::Broadcast.Broadcasted{<:SubbandStyle})
    _check_layouts(dest.layout, bc)
    copyto!(dest.data, Broadcast.instantiate(_storage(bc)))
    return dest
end

function Base.copyto!(dest::AbstractArray, bc::Broadcast.Broadcasted{<:SubbandStyle})
    c = _find_subbands(bc)
    _check_layouts(c.layout, bc)
    copyto!(dest, Broadcast.instantiate(_storage(bc)))
    return dest
end
