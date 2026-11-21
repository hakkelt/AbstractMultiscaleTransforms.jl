# Implementing a transform

A package implements the interface by subtyping
[`AbstractMultiscaleTransform`](@ref) and adding methods; the table in its
docstring lists which are required.  A sketch for a transform whose subbands
all have the size of the data:

```julia
using MultiscaleTransformsBase
import MultiscaleTransformsBase: analyze!, synthesize!, similar_coefficients,
    subband_layout, subband, make_workspace
using MultiscaleTransformsBase: check_workspace

struct MyTransform <: AbstractMultiscaleTransform
    scales::Int
end

subband_layout(t::MyTransform, dims::Dims) = ...      # lowpass first
similar_coefficients(t::MyTransform, x::AbstractArray) =
    similar(x, float(eltype(x)), (size(x)..., nsubbands(t, size(x))))
subband(::MyTransform, c::AbstractArray, i::Integer) = selectdim(c, ndims(c), i)

function analyze!(c, t::MyTransform, x; workspace = nothing, threaded = nothing)
    ws = workspace === nothing ? make_workspace(t, x) : workspace
    check_workspace(ws, t, float(eltype(x)), size(x))
    ...
    return c
end
```

and `synthesize!` likewise.  A transform with plans or buffers to reuse defines
its own workspace type (a subtype of [`AbstractTransformWorkspace`](@ref) with
[`transform`](@ref), `eltype` and `size`) and `make_workspace` methods,
which accept the shared keywords `flags`, `tasks`, `tune` and `prewarm` (see
[`make_workspace`](@ref)) and ignore those they have no use for;
otherwise the fallback [`MultiscaleTransformsBase.DefaultWorkspace`](@ref)
serves.  A transform with subbands of different sizes returns a
[`SubbandVector`](@ref) from `similar_coefficients` and gets `synthesize`'s
output size from its layout.

Conventions every implementation follows:

- The transform holds all parameters, is immutable and has value `==`/`hash`.
- Every call accepts `workspace` and `threaded` keywords.
- Errors are raised early, with a message: a wrong size is a
  `DimensionMismatch`, a wrong argument an `ArgumentError`.
- Nothing in the interface assumes a number of dimensions or a redundancy.

The package re-exports the interface's exported names, so that `using` it is
enough, and checks itself with the conformance suite:

```julia
using MultiscaleTransformsBase.Testing: test_transform
test_transform(MyTransform(3), randn(64, 64); wrong_size = (32, 32))
test_transform(MyTransform(3), randn(ComplexF32, 64, 64))
```
