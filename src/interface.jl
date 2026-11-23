# The generic functions of the interface, with their contracts.  Fallbacks here
# only forward between call forms; every transform computation is a method
# of the implementing package.

"""
    AbstractMultiscaleTransform

Supertype of transform objects.  A transform is an immutable value that holds
every parameter of the decomposition (number of scales, directions per scale,
filters, ...) and nothing that depends on the data's size or element type, so
one transform serves arrays of any admissible size.  Two transforms with equal
parameters are `==` and have equal `hash`.

An implementation defines, for its transform type `T`:

| Required | Purpose |
|:--|:--|
| `analyze!(c, t::T, x; workspace, threaded)` | analysis into preallocated coefficients |
| `synthesize!(x, t::T, c; workspace, threaded)` | synthesis into a preallocated array |
| `similar_coefficients(t::T, x)` | uninitialised coefficients for data like `x` |
| `subband_layout(t::T, dims)` | one descriptor per subband, lowpass first |
| `subband(t::T, c, i)` | subband `i` of `c`, a view |

| Optional | Default |
|:--|:--|
| `analyze(t::T, x; ...)` | `analyze!(similar_coefficients(t, x), t, x; ...)` |
| `synthesize(t::T, c; ...)` | `synthesize!` into an array of size `signal_size(t, c)` |
| `signal_size(t::T, c)` | needed by the default `synthesize`, except for `SubbandVector` coefficients |
| `make_workspace(t::T, T, dims; ...)` / `make_workspace(t::T, x; ...)` | a [`DefaultWorkspace`](@ref) |
| `nsubbands(t::T, dims)` | `length(subband_layout(t, dims))` |
| `analyze(f, t::T, x; ...)`, `synthesize!(f, x, t::T; ...)` with `supports_streaming(t::T) = true` | not supported |

Every implementation also follows these conventions;
[`Testing.test_transform`](@ref MultiscaleTransformsBase.Testing.test_transform)
checks most of them:

- The transform holds every parameter, is immutable, and two transforms with
  equal parameters are `==` and have equal `hash`.
- Every verb accepts the keywords `workspace` and `threaded`.  A method that
  receives a workspace checks it with [`check_workspace`](@ref) before using it.
- Wrong input throws before any work: a `DimensionMismatch` for a wrong size,
  an `ArgumentError` for another wrong argument, each with a message.
- Complex data is transformed as its real and imaginary parts, so that
  `analyze(t, x + im * y) ≈ analyze(t, x) + im * analyze(t, y)` for real `x`
  and `y`.
- The implementing package lists the interface's exported names in its own
  `export`, so that `using` it is enough.
"""
abstract type AbstractMultiscaleTransform end

"""
    AbstractTransformWorkspace

Supertype of workspaces: everything a transform precomputes for one data size,
element type and array type (filter responses, FFT plans, scratch buffers), so
that repeated calls allocate little or nothing.  Build one with
[`make_workspace`](@ref).

A workspace answers [`transform`](@ref), `eltype` (the data element type) and
`size` (the data size).  It holds scratch buffers, so it serves one call at a
time; give each task its own.  A call whose transform, size or element type
does not match the workspace throws (see [`check_workspace`](@ref)).

A workspace can stand in for its transform: `analyze(ws, x)` is
`analyze(transform(ws), x; workspace = ws)`, and likewise for the other verbs.

A transform that has plans or buffers to reuse defines its own subtype, with
methods for `transform`, `eltype` and `size`, and [`make_workspace`](@ref)
methods for `make_workspace(t, T, dims)` and, if the workspace depends on the
array type (a GPU array, say), for `make_workspace(t, x)`.  Both accept the
shared keywords listed there.  A transform without one gets a
[`DefaultWorkspace`](@ref).
"""
abstract type AbstractTransformWorkspace end

"""
    analyze(t, x; workspace = nothing, threaded = nothing) -> c
    analyze(ws, x; threaded = nothing) -> c

Analysis (forward) transform of the array `x` by the transform `t`.  The
coefficients `c` are an array: transforms whose subbands all have the size of
`x` stack them into one array of size `(size(x)..., n)`; others return a
[`SubbandVector`](@ref) or a package-specific array.  Read subbands with
[`subband`](@ref); [`synthesize`](@ref) inverts the transform.

`workspace` is a workspace from [`make_workspace`](@ref) matching `t` and
`x`; `threaded = nothing` leaves threading to the transform's documented
default, `true`/`false` asks for or against threads (a transform that never
threads ignores it).

    analyze(f, t, x; workspace = nothing, threaded = nothing) -> nothing

Streaming form (only where [`supports_streaming(t)`](@ref supports_streaming)):
calls `f(i, band)` once for every subband `i` instead of storing the
coefficients.  `band` is valid only until `f` returns.
"""
function analyze end

"""
    analyze!(c, t, x; workspace = nothing, threaded = nothing) -> c
    analyze!(c, ws, x; threaded = nothing) -> c

[`analyze`](@ref) into the preallocated coefficients `c` (from
[`similar_coefficients`](@ref) or an earlier `analyze`).
"""
function analyze! end

"""
    synthesize(t, c; workspace = nothing, threaded = nothing) -> x
    synthesize(ws, c; threaded = nothing) -> x

Synthesis transform: the array whose analysis is `c`, so that
`synthesize(t, analyze(t, x)) ≈ x`.  This is the adjoint of [`analyze`](@ref)
only when the transform is a tight (Parseval) frame; each package documents
whether its transforms are.
"""
function synthesize end

"""
    synthesize!(x, t, c; workspace = nothing, threaded = nothing) -> x
    synthesize!(x, ws, c; threaded = nothing) -> x

[`synthesize`](@ref) into the preallocated array `x`.

    synthesize!(f, x, t; workspace = nothing, threaded = nothing) -> x

Streaming form (only where [`supports_streaming(t)`](@ref supports_streaming)):
subband `i` is `f(i)`; the size, element type and device of the result are
those of `x`.
"""
function synthesize! end

"""
    make_workspace(t, T::Type{<:Number}, dims; kwargs...) -> AbstractTransformWorkspace
    make_workspace(t, x::AbstractArray; kwargs...) -> AbstractTransformWorkspace

Precompute what transform `t` needs for data of element type `T` and size
`dims`.  The second form takes element type, size and array type (so the
device) from `x`.

Every transform accepts these keywords on both forms, so that code can build a
workspace without knowing the transform family.  A transform with no use for
one accepts and ignores it, and says so in its documentation; the defaults are
the transform's own (its fastest choice).

- `flags`: the FFTW planner flags of the host FFT plans (an integer, such as
  `FFTW.MEASURE` or `FFTW.ESTIMATE`).
- `tasks`: the most tasks a call with the workspace runs on the host, and with
  them the per-task buffers; `nothing` means one per Julia thread, `1` a
  serial workspace.
- `tune`: measure the fastest batching of a device workspace at construction
  (a `Bool`).
- `prewarm`: run the transform once at construction, so that the first call
  is compiled and allocates nothing (a `Bool`).

A transform may accept further keywords of its own.  An unknown keyword throws
a `MethodError`.

Without a method for `t`, both return a [`DefaultWorkspace`](@ref), which
holds nothing but `(t, T, dims)` and ignores the keywords above.
"""
make_workspace(
    t::AbstractMultiscaleTransform, ::Type{T}, dims::Dims;
    flags::Union{Integer, Nothing} = nothing, tasks::Union{Integer, Nothing} = nothing,
    tune::Bool = false, prewarm::Bool = false
) where {T <: Number} = DefaultWorkspace(t, T, dims)
make_workspace(t::AbstractMultiscaleTransform, x::AbstractArray; kwargs...) =
    make_workspace(t, eltype(x), size(x); kwargs...)

"""
    transform(ws::AbstractTransformWorkspace) -> AbstractMultiscaleTransform

The transform `ws` was built for.
"""
function transform end

"""
    similar_coefficients(t, x::AbstractArray) -> c

Uninitialised coefficients of `t` for data like `x` (same size, element type
family and array type), for [`analyze!`](@ref).
"""
function similar_coefficients end

"""
    subband_layout(t, dims) -> AbstractVector

One descriptor per subband of `t` on data of size `dims`, in the order of
[`subband`](@ref)'s index; the first is the lowpass.  What a descriptor holds
(scale, direction, ...) is transform-specific.
"""
function subband_layout end

"""
    nsubbands(t, dims) -> Int

Number of subbands, the lowpass included, of `t` on data of size `dims`.
"""
nsubbands(t::AbstractMultiscaleTransform, dims::Dims) = length(subband_layout(t, dims))

"""
    subband(t, c, i) -> AbstractArray
    subband(c::SubbandVector, i) -> AbstractArray

Subband `i` of the coefficients `c` of transform `t`, as a view (writing to
it changes `c`).  Subband 1 is the lowpass; [`subband_layout`](@ref) describes
the others.
"""
function subband end

"""
    signal_size(t, c) -> Dims

Size of the data that the coefficients `c` of `t` synthesize to, used by the
default [`synthesize`](@ref) when no workspace is given.  The default reads a
[`SubbandVector`](@ref)'s size from its layout without calling this function;
other coefficient types need a method.
"""
function signal_size end

"""
    supports_streaming(t) -> Bool

Whether `t` implements the streaming forms `analyze(f, t, x)` and
`synthesize!(f, x, t)`.  `false` unless the implementing package says otherwise.
"""
supports_streaming(::AbstractMultiscaleTransform) = false

# ── Defaults between call forms ─────────────────────────────────────────────

function analyze(t::AbstractMultiscaleTransform, x::AbstractArray; workspace = nothing, threaded = nothing)
    return analyze!(similar_coefficients(t, x), t, x; workspace, threaded)
end

function synthesize(t::AbstractMultiscaleTransform, c::AbstractArray; workspace = nothing, threaded = nothing)
    dims = workspace === nothing ? _signal_size(t, c) : size(workspace)
    T = workspace === nothing ? eltype(c) : eltype(workspace)
    return synthesize!(similar(c, T, dims), t, c; workspace, threaded)
end

analyze(ws::AbstractTransformWorkspace, x::AbstractArray; threaded = nothing) =
    analyze(transform(ws), x; workspace = ws, threaded)
analyze!(c::AbstractArray, ws::AbstractTransformWorkspace, x::AbstractArray; threaded = nothing) =
    analyze!(c, transform(ws), x; workspace = ws, threaded)
synthesize(ws::AbstractTransformWorkspace, c::AbstractArray; threaded = nothing) =
    synthesize(transform(ws), c; workspace = ws, threaded)
synthesize!(x::AbstractArray, ws::AbstractTransformWorkspace, c::AbstractArray; threaded = nothing) =
    synthesize!(x, transform(ws), c; workspace = ws, threaded)
analyze(f, ws::AbstractTransformWorkspace, x::AbstractArray; threaded = nothing) =
    analyze(f, transform(ws), x; workspace = ws, threaded)
synthesize!(f, x::AbstractArray, ws::AbstractTransformWorkspace; threaded = nothing) =
    synthesize!(f, x, transform(ws); workspace = ws, threaded)
