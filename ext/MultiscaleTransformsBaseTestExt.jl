module MultiscaleTransformsBaseTestExt

using Test: @test, @testset, @test_throws
using LinearAlgebra: LinearAlgebra
using MultiscaleTransformsBase: MultiscaleTransformsBase, AbstractMultiscaleTransform,
    analyze, analyze!, synthesize, synthesize!, make_workspace, transform, similar_coefficients,
    subband_layout, nsubbands, subband, supports_streaming
import MultiscaleTransformsBase.Testing: test_transform

function test_transform(
        t::AbstractMultiscaleTransform, x::AbstractArray;
        rtol::Real = sqrt(eps(real(float(eltype(x))))), wrong_size = nothing, exact_real_linear::Bool = false
    )
    return @testset "interface conformance: $(nameof(typeof(t)))" begin
        dims = size(x)
        c = analyze(t, x)
        @test c isa AbstractArray
        n = nsubbands(t, dims)
        @test n == length(subband_layout(t, dims))
        @test n >= 1
        bands = [subband(t, c, i) for i in 1:n]
        @test all(b -> b isa AbstractArray, bands)
        @test sum(length, bands) == length(c)

        y = synthesize(t, c)
        @test size(y) == dims
        @test isapprox(y, x; rtol)

        c2 = similar_coefficients(t, x)
        @test analyze!(c2, t, x) === c2
        @test isapprox(c2, c; rtol)
        y2 = similar(y)
        @test synthesize!(y2, t, c) === y2
        @test isapprox(y2, x; rtol)

        for threaded in (false, true)
            @test isapprox(analyze(t, x; threaded), c; rtol)
            @test isapprox(synthesize(t, c; threaded), x; rtol)
        end

        ws = make_workspace(t, x)
        @test transform(ws) == t
        @test size(ws) == dims
        @test isapprox(analyze(t, x; workspace = ws), c; rtol)
        @test isapprox(analyze(ws, x), c; rtol)
        fill!(c2, zero(eltype(c2)))
        @test analyze!(c2, ws, x) === c2
        @test isapprox(c2, c; rtol)
        @test isapprox(synthesize(t, c; workspace = ws), x; rtol)
        @test isapprox(synthesize(ws, c), x; rtol)
        @test synthesize!(y2, ws, c) === y2
        @test isapprox(y2, x; rtol)

        @test t == deepcopy(t)
        @test hash(t) == hash(deepcopy(t))

        d = 2 .* c .+ c
        @test typeof(d) == typeof(c)
        @test isapprox(d, 3 .* c; rtol)
        e = similar(c)
        @test copyto!(e, c) == c
        @test LinearAlgebra.norm(c)^2 ≈ real(LinearAlgebra.dot(c, c))

        if supports_streaming(t)
            seen = falses(n)
            r = analyze(t, x) do i, band
                seen[i] = true
                @test isapprox(band, subband(t, c, i); rtol, atol = rtol * LinearAlgebra.norm(c))
                return nothing
            end
            @test r === nothing
            @test all(seen)
            y3 = similar(y)
            @test synthesize!(i -> subband(t, c, i), y3, t) === y3
            @test isapprox(y3, x; rtol)
        end

        if wrong_size !== nothing
            other = make_workspace(t, eltype(x), Tuple(wrong_size))
            @test_throws DimensionMismatch analyze(t, x; workspace = other)
        end

        if eltype(x) <: Complex
            # Through workspaces built once: a call without one may plan its
            # FFTs differently from an earlier call, which can change rounding.
            ws_real = make_workspace(t, real(x))
            whole = analyze(t, x; workspace = ws)
            parts = complex.(analyze(t, real(x); workspace = ws_real), analyze(t, imag(x); workspace = ws_real))
            if exact_real_linear
                @test whole == parts
            else
                @test isapprox(whole, parts; rtol)
            end
        end
    end
end

end # module
