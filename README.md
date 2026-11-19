# MultiscaleTransformsBase.jl

An interface for multiscale transforms (wavelets, contourlets, surfacelets,
shearlets): transform objects holding their parameters, the verbs
`analyze`/`analyze!`/`synthesize`/`synthesize!`, reusable workspaces, and
array-valued coefficients with subband access.  It defines no transform itself;
packages implementing it re-export its names:

- [Contourlets.jl](https://github.com/hakkelt/Contourlets.jl)
- [Surfacelets.jl](https://github.com/hakkelt/Surfacelets.jl)
- [Shearlets.jl](https://github.com/hakkelt/Shearlets.jl)

```julia
using Shearlets
t = BandlimitedShearlets(scales = 3)
c = analyze(t, x)          # an array; subband(t, c, i) is a view of subband i
x̂ = synthesize(t, c)      # ≈ x

ws = make_workspace(t, x)  # precomputed plans and buffers for repeated calls
analyze!(c, ws, x)
```

An implementation checks itself with
`MultiscaleTransformsBase.Testing.test_transform(t, x)`.  See the
documentation for the full contract.
