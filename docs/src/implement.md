# Implement a transform

This page shows how to make a new transform usable through the
MultiscaleTransformsBase interface and how to check it with the conformance
tests. The full contract, the required and optional methods and the conventions
every implementation follows, is in the docstrings of
[`AbstractMultiscaleTransform`](@ref) and [`AbstractTransformWorkspace`](@ref).

## Define the transform

A transform is an immutable subtype of [`AbstractMultiscaleTransform`](@ref)
that holds the parameters of the decomposition, with methods for
`analyze!`, `synthesize!`, `similar_coefficients`, `subband_layout` and
`subband`. The example below splits an array into two subbands: a lowpass,
the circular moving average of three samples along the first axis, and the
remainder. Synthesis adds them. Both subbands have the size of the data, so
the coefficients are one array of size `(size(x)..., 2)`, with subband `i`
the slice `i` along the last axis.

```@example twoband
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

When subbands have different sizes, `similar_coefficients` returns a
[`SubbandVector`](@ref) instead, and `subband(t, c, i)` forwards to
`subband(c, i)`. `synthesize` then reads the data size from the
[`SubbandLayout`](@ref), so no `signal_size` method is needed.

A transform that precomputes plans or buffers adds its own workspace type (see
[`AbstractTransformWorkspace`](@ref)); one that can produce or consume one
subband at a time adds the streaming forms (see
[`MultiscaleTransformsBase.supports_streaming`](@ref)).

## Run the conformance tests

[`MultiscaleTransformsBase.Testing.test_transform`](@ref) runs the interface's
checks in a `@testset`. It needs the `Test` standard library loaded. Run it on
real and complex data in the package's test suite:

```@example twoband
using Test
using MultiscaleTransformsBase.Testing: test_transform

test_transform(TwoBand(), randn(8, 6); wrong_size = (4, 6))
test_transform(TwoBand(), randn(ComplexF64, 8, 6))
nothing # hide
```

`wrong_size` is a data size for which a workspace must be rejected; the
docstring lists the other keywords.
