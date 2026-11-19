"""
    DefaultWorkspace(t, T, dims)

The workspace of a transform that precomputes nothing: it records the
transform, data element type `T` and data size `dims`, so that the workspace
forms of the verbs and [`check_workspace`](@ref) work for every transform.
Returned by the fallback [`make_workspace`](@ref).
"""
struct DefaultWorkspace{Tt <: AbstractMultiscaleTransform, T <: Number, N} <: AbstractTransformWorkspace
    transform::Tt
    dims::NTuple{N, Int}
    DefaultWorkspace{Tt, T, N}(t, dims) where {Tt <: AbstractMultiscaleTransform, T <: Number, N} = new{Tt, T, N}(t, dims)
end

DefaultWorkspace(t::AbstractMultiscaleTransform, ::Type{T}, dims::Dims{N}) where {T <: Number, N} =
    DefaultWorkspace{typeof(t), T, N}(t, dims)

transform(ws::DefaultWorkspace) = ws.transform
Base.eltype(::Type{<:DefaultWorkspace{Tt, T}}) where {Tt, T} = T
Base.size(ws::DefaultWorkspace) = ws.dims

function Base.show(io::IO, ws::DefaultWorkspace)
    print(io, "DefaultWorkspace(")
    show(io, ws.transform)
    return print(io, ", ", eltype(ws), ", ", ws.dims, ")")
end

"""
    check_workspace(ws, t, T, dims) -> ws

Throw unless workspace `ws` was built for transform `t`, data element type `T`
and data size `dims`: an `ArgumentError` for another transform or element
type, a `DimensionMismatch` for another size.  Implementations call it on a
`workspace` keyword before using it.
"""
function check_workspace(ws::AbstractTransformWorkspace, t::AbstractMultiscaleTransform, ::Type{T}, dims::Dims) where {T}
    transform(ws) == t ||
        throw(ArgumentError("the workspace was built for $(transform(ws)), not for $(t)"))
    eltype(ws) === T ||
        throw(ArgumentError("the workspace was built for element type $(eltype(ws)), not for $(T)"))
    size(ws) == dims ||
        throw(DimensionMismatch("the workspace was built for data of size $(size(ws)), not $(dims)"))
    return ws
end
