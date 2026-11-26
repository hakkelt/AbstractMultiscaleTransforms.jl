"""
    AbstractMultiscaleTransforms.Testing

Conformance tests for implementations of the interface; see
[`test_transform`](@ref AbstractMultiscaleTransforms.Testing.test_transform).
Its method is defined once the `Test` standard library is loaded.
"""
module Testing

"""
    test_transform(t, x; rtol, wrong_size = nothing, exact_real_linear = false)

Needs the `Test` standard library loaded (`using Test`), which defines the method.

Run the interface's conformance tests for transform `t` on data `x`, inside a
`@testset`:

- `analyze` returns an array, whose `nsubbands(t, size(x))` subbands cover all
  of its entries; `synthesize` reconstructs `x` (to `rtol`);
- `analyze!`/`synthesize!` into preallocated arrays, the workspace (`make_workspace`)
  and workspace-only forms, and `threaded = true`/`false` give the same results;
- both `make_workspace` forms accept the shared keywords `flags`, `tasks`,
  `tune` and `prewarm`, the workspace built with them gives the same results,
  and an unknown keyword throws a `MethodError`;
- the transform equals its copy, with an equal hash;
- broadcasting, `similar`, `copyto!`, `norm` and `dot` work on the coefficients;
- the streaming forms, if `supports_streaming(t)`, give the same subbands and
  reconstruction;
- a workspace for another size (`wrong_size`, when given) is rejected;
- for real `x` and `preserves_real(t)`, the coefficients are real;
- for complex `x`, the transform is linear over the complex numbers:
  `analyze(t, x) ≈ analyze(t, real(x)) + im * analyze(t, imag(x))`, exactly
  (`==`) when `exact_real_linear` (meaningful when `preserves_real(t)`, where
  the right side is formed with `complex.`); each side runs through a
  workspace built once, so that FFT planning between calls cannot change the
  rounding.
"""
function test_transform(t, x; kwargs...)
    if Base.get_extension(parentmodule(@__MODULE__), :AbstractMultiscaleTransformsTestExt) === nothing
        # A missing package extension has no dedicated exception type.
        # lint-disable-next-line: Use custom exception instead of the generic
        error("`test_transform` is defined once the Test standard library is loaded: run `using Test` first.")
    end
    throw(MethodError(test_transform, (t, x)))
end

end # module
