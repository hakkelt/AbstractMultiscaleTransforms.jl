# Use a transform

This page shows how to call any transform that implements the
MultiscaleTransformsBase interface. The examples use
`BandlimitedShearlets` from [Shearlets.jl](https://github.com/hakkelt/Shearlets.jl);
the same calls work for the transforms of Contourlets.jl and Surfacelets.jl.

A *transform* is an immutable object that holds the parameters of the
decomposition (number of scales, directions, filters). It does not depend on
the size of the data, so one transform serves arrays of any size it accepts.

## Analyze and synthesize

[`analyze`](@ref) computes the coefficients; [`synthesize`](@ref) computes the
data back from them:

```julia
using Shearlets

x = randn(256, 256)
t = BandlimitedShearlets(scales = 3)
c = analyze(t, x)
y = synthesize(t, c)        # y ≈ x
```

The coefficients `c` are an array. Transforms whose subbands all have the size
of `x` return one array of size `(size(x)..., n)` with the `n` subbands along
the last axis. Transforms with subbands of different sizes return a
[`SubbandVector`](@ref) (Contourlets' `CT` and `STICT`, Surfacelets'
`Surfacelet`).

## Read the subbands

```julia
using Shearlets

x = randn(256, 256)
t = BandlimitedShearlets(scales = 3)
c = analyze(t, x)

n = nsubbands(t, size(x))          # number of subbands, the lowpass included
low = subband(t, c, 1)             # subband 1 is the lowpass
info = subband_layout(t, size(x))  # one descriptor per subband
```

[`subband`](@ref) returns a view: writing to it changes `c`. What a
descriptor in [`subband_layout`](@ref) holds (scale, direction, ...) depends on
the transform; its package documents it.

## Process coefficients

Coefficients of either kind broadcast and support `norm`, `dot`, `axpy!` and
the other operations of iterative solvers. For example, soft thresholding
followed by synthesis:

```julia
using Shearlets

x = randn(256, 256)
t = BandlimitedShearlets(scales = 3)
c = analyze(t, x)

λ = 0.1
c .= sign.(c) .* max.(abs.(c) .- λ, 0)
y = synthesize(t, c)
```

A broadcast over `SubbandVector`s returns a `SubbandVector` with the same
layout; operands with different layouts throw a `DimensionMismatch`.

## Reuse a workspace

A *workspace* holds what a transform computes in advance for one data size,
element type and array type, such as filter responses, FFT plans and scratch
buffers. Build it once with [`make_workspace`](@ref) and pass it to repeated
calls, so they do not repeat that work:

```julia
using Shearlets

x = randn(256, 256)
t = BandlimitedShearlets(scales = 3)

ws = make_workspace(t, x)             # or make_workspace(t, Float64, (256, 256))
c = similar_coefficients(t, x)
for k in 1:10
    analyze!(c, t, x; workspace = ws) # or analyze!(c, ws, x)
    # ... change c ...
    synthesize!(x, ws, c)             # or synthesize!(x, t, c; workspace = ws)
end
```

- A call whose transform, data size or element type does not match the
  workspace throws.
- A workspace holds scratch buffers, so it serves one call at a time. Give
  each task its own workspace.
- `make_workspace` takes the keywords `flags`, `tasks`, `tune` and `prewarm`
  for every transform; see its docstring. For example,
  `make_workspace(t, x; tasks = 1)` builds a serial workspace with one set of
  buffers.

## Choose threading

Every call accepts `threaded`: `true` asks for threads, `false` asks against
them, and `nothing` (the default) leaves the choice to the transform. A
transform that never uses threads ignores it.

```julia
c = analyze(t, x; threaded = false)
```

## Stream subbands

When the coefficients do not fit in memory, a transform with
`MultiscaleTransformsBase.supports_streaming(t) == true` can hand the subbands
to a function one at a time (the Shearlets.jl systems and Surfacelets'
`NSSurfacelet` support this):

```julia
using Shearlets

x = randn(256, 256)
t = BandlimitedShearlets(scales = 3)
n = nsubbands(t, size(x))

energy = zeros(n)
analyze(t, x) do i, band
    energy[i] = sum(abs2, band)   # band is valid only until this function returns
end
```

The synthesis asks a function for subband `i` and writes the result into a
preallocated array:

```julia
y = similar(x)
c = analyze(t, x)
synthesize!(i -> subband(t, c, i), y, t)
```

## Use GPU arrays

Where a transform package supports GPUs, pass device arrays: the coefficients
and workspaces take their array type from `x`. Build the workspace from device
data:

```julia
using Shearlets, CUDA

x = CuArray(randn(Float32, 256, 256))
t = BandlimitedShearlets(scales = 3)
ws = make_workspace(t, x)
c = analyze(t, x; workspace = ws)
```

`Adapt.adapt` moves a `SubbandVector` between host and device, for example
`adapt(CuArray, c)`.
