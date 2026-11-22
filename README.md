# MultiscaleTransformsBase.jl

A common interface for multiscale transforms such as wavelets, contourlets,
surfacelets and shearlets: transform objects, the functions `analyze` and
`synthesize`, reusable workspaces, and array-valued coefficients with access to
each subband. Code written against it works with any transform that implements
it. The package defines no transform itself; these packages implement it and
re-export its names:

- [Contourlets.jl](https://github.com/hakkelt/Contourlets.jl) (2-D)
- [Surfacelets.jl](https://github.com/hakkelt/Surfacelets.jl) (3-D)
- [Shearlets.jl](https://github.com/hakkelt/Shearlets.jl) (2-D and 3-D)

## Installation

The package is not registered yet. The transform packages above install it as
a dependency; follow their instructions. To work with the interface alone,
clone it and develop it into your environment:

```bash
git clone https://github.com/hakkelt/MultiscaleTransformsBase.jl MultiscaleTransformsBase
```

```julia
using Pkg
Pkg.develop(path = "MultiscaleTransformsBase")
```

## Example

```julia
using Shearlets

x = randn(256, 256)
t = BandlimitedShearlets(scales = 3)
c = analyze(t, x)          # an array; subband(t, c, i) is a view of subband i
synthesize(t, c) ≈ x       # true
```

The [documentation](https://hakkelt.github.io/MultiscaleTransformsBase.jl/dev/)
explains how to use transforms, reuse workspaces and stream subbands, and how
to implement the interface for a new transform and test it.

## License

MIT; see [`LICENSE`](LICENSE). Third-party notices are in [`NOTICE`](NOTICE).

## Disclaimer

This package was created by [Claude](https://claude.com/claude-code), Anthropic's
AI model, under the direction of the author.
