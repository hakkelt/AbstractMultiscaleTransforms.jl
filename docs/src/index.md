# MultiscaleTransformsBase.jl

MultiscaleTransformsBase.jl is a common interface for multiscale transforms such
as wavelets, contourlets, surfacelets and shearlets. A multiscale transform
splits an array into *subbands*: a lowpass subband with the coarse content, and
detail subbands, each holding one scale (and, for directional transforms, one
direction). Every transform that implements the interface is used through the
same functions, so code written for one works with another by changing only
the transform object.

The package defines no transform itself. These packages implement it and
re-export its names:

- [Contourlets.jl](https://github.com/hakkelt/Contourlets.jl): 2-D contourlet
  transforms (`CT`, `NSCT`, `TICT`, `STICT`).
- [Surfacelets.jl](https://github.com/hakkelt/Surfacelets.jl): 3-D surfacelet
  transforms (`Surfacelet`, `NSSurfacelet`).
- [Shearlets.jl](https://github.com/hakkelt/Shearlets.jl): 2-D and 3-D
  shearlet transforms (`BandlimitedShearlets`, `NSSTShearlets`,
  `CompactShearlets`).

## Installation

The package is not registered yet. If you use one of the transform packages
above, follow its installation instructions; they install this package too.
To work with the interface alone, clone it and develop it into your
environment:

```bash
git clone https://github.com/hakkelt/MultiscaleTransformsBase.jl MultiscaleTransformsBase
```

```julia
using Pkg
Pkg.develop(path = "MultiscaleTransformsBase")
```

## Example

With Shearlets.jl installed:

```julia
using Shearlets

x = randn(256, 256)
t = BandlimitedShearlets(scales = 3)   # the transform: its parameters only
c = analyze(t, x)                      # coefficients, an array
subband(t, c, 1)                       # the lowpass subband, a view into c
synthesize(t, c) ≈ x                   # true
```

## Where to go next

- [Use a transform](@ref): analysis, synthesis, subbands, workspaces, threads,
  streaming and GPU arrays.
- [Implement a transform](@ref): add the interface to a new transform and run
  the conformance tests.
- [Concepts](@ref): transforms, workspaces and the two ways coefficients are
  stored.
- [API reference](@ref): every public name.
