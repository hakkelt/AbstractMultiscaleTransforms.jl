# Implement a transform

This page shows how to make a new transform usable through the
MultiscaleTransformsBase interface and how to check it with the conformance
tests. A *transform* here is an immutable type, a subtype of
[`AbstractMultiscaleTransform`](@ref), that holds the parameters of the
decomposition. The functions it must implement and the optional ones, with
their defaults, are listed in the docstring of
[`AbstractMultiscaleTransform`](@ref).

## A transform with stacked coefficients

When every subband has the size of the data, store the coefficients as one
array of size `(size(x)..., n)`, with subband `i` the slice `i` along the last
axis. The example below splits an array into two subbands: a lowpass, the
circular moving average of three samples along the first axis, and the
remainder. Synthesis adds them.

```@example stacked
using MultiscaleTransformsBase
import MultiscaleTransformsBase: analyze!, synthesize!, similar_coefficients,
    subband_layout, subband, signal_size
using MultiscaleTransformsBase: check_workspace

struct TwoBand <: AbstractMultiscaleTransform end

subband_layout(::TwoBand, dims::Dims) = [:lowpass, :detail]
similar_coefficients(t::TwoBand, x::AbstractArray) =
    similar(x, float(eltype(x)), (size(x)..., nsubbands(t, size(x))))
subband(::TwoBand, c::AbstractArray, i::Integer) = selectdim(c, ndims(c), i)
signal_size(::TwoBand, c::AbstractArray) = size(c)[1:(end - 1)]

function analyze!(c::AbstractArray, t::TwoBand, x::AbstractArray;
        workspace = nothing, threaded = nothing)
    workspace === nothing || check_workspace(workspace, t, eltype(x), size(x))
    size(c) == (size(x)..., 2) ||
        throw(DimensionMismatch("coefficients of size $(size(c)) do not fit data of size $(size(x))"))
    low = subband(t, c, 1)
    low .= (circshift(x, 1) .+ x .+ circshift(x, -1)) ./ 3
    subband(t, c, 2) .= x .- low
    return c
end

function synthesize!(x::AbstractArray, t::TwoBand, c::AbstractArray;
        workspace = nothing, threaded = nothing)
    workspace === nothing || check_workspace(workspace, t, eltype(x), size(x))
    x .= subband(t, c, 1) .+ subband(t, c, 2)
    return x
end

x = randn(8, 6)
c = analyze(TwoBand(), x)
size(c), synthesize(TwoBand(), c) ≈ x
```

The interface supplies the rest: `analyze` and `synthesize` allocate and call
the in-place methods, `nsubbands` counts the layout, and `make_workspace`
returns a [`MultiscaleTransformsBase.DefaultWorkspace`](@ref), which records
the transform, element type and size so that
[`MultiscaleTransformsBase.check_workspace`](@ref) can reject a mismatched
workspace.

## A transform with subbands of different sizes

When subband sizes differ, return a [`SubbandVector`](@ref) from
`similar_coefficients`. A [`SubbandLayout`](@ref) lists the subband sizes and
the data size; `synthesize` reads the output size from it, so no
`signal_size` method is needed. The example is an orthonormal 1-D Haar wavelet
transform with `levels` levels:

```@example ragged
using MultiscaleTransformsBase
import MultiscaleTransformsBase: analyze!, synthesize!, similar_coefficients,
    subband_layout, subband
using MultiscaleTransformsBase: check_workspace

struct Haar <: AbstractMultiscaleTransform
    levels::Int
end

# Lowpass first, then the details from coarse to fine.
function haar_layout(t::Haar, dims::Dims{1})
    n = dims[1]
    n % 2^t.levels == 0 ||
        throw(DimensionMismatch("length $n is not divisible by 2^$(t.levels)"))
    sizes = [(n >> t.levels,); [(n >> l,) for l in t.levels:-1:1]]
    return SubbandLayout(sizes, dims)
end

subband_layout(t::Haar, dims::Dims{1}) = haar_layout(t, dims).sizes
similar_coefficients(t::Haar, x::AbstractVector) =
    SubbandVector{float(eltype(x))}(undef, haar_layout(t, size(x)), x)
subband(::Haar, c::SubbandVector, i::Integer) = subband(c, i)

function analyze!(c::SubbandVector, t::Haar, x::AbstractVector;
        workspace = nothing, threaded = nothing)
    workspace === nothing || check_workspace(workspace, t, eltype(x), size(x))
    a = float.(x)
    for l in 1:t.levels
        even, odd = a[1:2:end], a[2:2:end]
        subband(c, t.levels + 2 - l) .= (even .- odd) ./ sqrt(2)
        a = (even .+ odd) ./ sqrt(2)
    end
    subband(c, 1) .= a
    return c
end

function synthesize!(x::AbstractVector, t::Haar, c::SubbandVector;
        workspace = nothing, threaded = nothing)
    workspace === nothing || check_workspace(workspace, t, eltype(x), size(x))
    a = copy(subband(c, 1))
    for l in t.levels:-1:1
        d = subband(c, t.levels + 2 - l)
        b = similar(a, 2 * length(a))
        b[1:2:end] .= (a .+ d) ./ sqrt(2)
        b[2:2:end] .= (a .- d) ./ sqrt(2)
        a = b
    end
    x .= a
    return x
end

x = randn(16)
c = analyze(Haar(2), x)
[size(subband(c, i)) for i in 1:nsubbands(c)], synthesize(Haar(2), c) ≈ x
```

## Conventions

The conformance tests below check most of these; the rest are expected of
every implementation:

- The transform holds every parameter, is immutable, and two transforms with
  equal parameters are `==` and have equal `hash`.
- Every verb accepts the keywords `workspace` and `threaded`. A method that
  receives a workspace checks it with
  [`MultiscaleTransformsBase.check_workspace`](@ref) before using it.
- Wrong input throws before any work: a `DimensionMismatch` for a wrong size,
  an `ArgumentError` for another wrong argument, each with a message.
- Complex data is transformed as its real and imaginary parts, so that
  `analyze(t, x + im * y) ≈ analyze(t, x) + im * analyze(t, y)` for real `x`
  and `y`.
- The package lists the interface's exported names in its own `export`, so
  that `using` it is enough.

## Add a workspace type

A transform that has plans or buffers to reuse defines its own workspace: a
subtype of [`AbstractTransformWorkspace`](@ref) with methods for
[`transform`](@ref), `eltype` (the data element type) and `size` (the data
size), and [`make_workspace`](@ref) methods for the form
`make_workspace(t, T, dims)`, and for `make_workspace(t, x)` if the workspace
depends on the array type of `x` (a GPU array, say). Both forms accept the
keywords `flags`, `tasks`, `tune` and `prewarm`, ignoring those the transform
has no use for, and throw a `MethodError` for any other keyword.

## Support streaming

A transform that can produce or consume one subband at a time adds
`MultiscaleTransformsBase.supports_streaming(::MyTransform) = true` and
methods for `analyze(f, t, x; workspace, threaded)`, which calls `f(i, band)`
for every subband, and `synthesize!(f, x, t; workspace, threaded)`, which
takes subband `i` from `f(i)`. See [`analyze`](@ref) and
[`synthesize!`](@ref).

## Run the conformance tests

[`MultiscaleTransformsBase.Testing.test_transform`](@ref) runs the interface's
checks in a `@testset`: round trip, in-place and workspace forms, workspace
keywords, `==` and `hash`, coefficient arithmetic, streaming when supported,
and real-linearity for complex data. It needs the `Test` standard library
loaded. Run it on real and complex data in the package's test suite:

```@example ragged
using Test
using MultiscaleTransformsBase.Testing: test_transform

test_transform(Haar(3), randn(32); wrong_size = (16,))
test_transform(Haar(2), randn(ComplexF64, 16))
nothing # hide
```

`wrong_size` is a data size for which a workspace must be rejected; the
docstring lists the other keywords.
