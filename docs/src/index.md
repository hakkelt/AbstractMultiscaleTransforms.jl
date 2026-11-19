# MultiscaleTransformsBase.jl

An interface for multiscale transforms — wavelets, contourlets, surfacelets,
shearlets — so that code using one can switch to another by changing the
transform object only.  The package defines no transform itself; the transform
packages implement it:

- [Contourlets.jl](https://github.com/hakkelt/Contourlets.jl): contourlet,
  nonsubsampled and translation-invariant contourlet transforms (2-D);
- [Surfacelets.jl](https://github.com/hakkelt/Surfacelets.jl): decimated and
  nonsubsampled surfacelet transforms (3-D);
- [Shearlets.jl](https://github.com/hakkelt/Shearlets.jl): band-limited,
  compactly supported and nonsubsampled shearlets (2-D and 3-D).

## Using a transform

A transform is a value holding its parameters.  [`analyze`](@ref) computes the
coefficients, [`synthesize`](@ref) reconstructs the data:

```julia
using Shearlets                       # re-exports analyze, synthesize, ...
t = BandlimitedShearlets(scales = 3)
c = analyze(t, x)                     # an array
x̂ = synthesize(t, c)                 # ≈ x
```

Coefficients are arrays, so they broadcast and work with `norm`, `dot` and
the in-place `LinearAlgebra` operations an iterative solver needs
(`soft = sign.(c) .* max.(abs.(c) .- λ, 0)`).  Transforms whose subbands all
have the size of the data stack them along a trailing axis, giving an array of
size `(size(x)..., n)`; transforms with subbands of different sizes return a
[`SubbandVector`](@ref).  Either way [`subband(t, c, i)`](@ref subband) is a
view of subband `i` (subband 1 is the lowpass), [`nsubbands`](@ref) counts
them and [`subband_layout`](@ref) describes them.

## Repeated calls

A workspace holds what a transform precomputes for one data size, element type
and device (filter responses, FFT plans, buffers):

```julia
ws = make_workspace(t, x)             # or make_workspace(t, Float32, (256, 256))
c = similar_coefficients(t, x)
for k in 1:100
    analyze!(c, t, x; workspace = ws) # or analyze!(c, ws, x)
    # ...
    synthesize!(x, t, c; workspace = ws)
end
```

A workspace serves one call at a time; give each task its own.  Every call
accepts `threaded = true`/`false` to ask for or against threads, and
`nothing` (the default) for the transform's own choice.

## Streaming

Where [`MultiscaleTransformsBase.supports_streaming(t)`](@ref
MultiscaleTransformsBase.supports_streaming), `analyze(f, t, x)` hands each
subband to `f(i, band)` instead of storing all of them, and
`synthesize!(f, x, t)` asks `f(i)` for them — for data whose coefficients do
not fit in memory.
