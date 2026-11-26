@testitem "conformance: stacked toy transform" tags = [:interface] setup = [ToyTransforms] begin
    using AbstractMultiscaleTransforms.Testing: test_transform
    using .ToyTransforms: Split
    test_transform(Split(3), randn(8, 6); wrong_size = (4, 6))
    test_transform(Split(2), randn(ComplexF64, 5, 4, 3); exact_real_linear = true)
    test_transform(Split(1), randn(Float32, 7))
end

@testitem "conformance: ragged toy transform" tags = [:interface] setup = [ToyTransforms] begin
    using AbstractMultiscaleTransforms.Testing: test_transform
    using .ToyTransforms: Haar
    test_transform(Haar(3), randn(32); wrong_size = (16,))
    test_transform(Haar(2), randn(ComplexF64, 16); exact_real_linear = true)
end

@testitem "conformance: complex-filter toy transform" tags = [:interface] setup = [ToyTransforms] begin
    using AbstractMultiscaleTransforms.Testing: test_transform
    using AbstractMultiscaleTransforms: preserves_real
    using .ToyTransforms: Modulate, Split
    using LinearAlgebra: norm
    t = Modulate(3)
    @test !preserves_real(t)
    @test preserves_real(Split(2))
    x = randn(6, 5)
    c = analyze(t, x)
    @test eltype(c) == ComplexF64
    @test norm(c) ≈ norm(x)
    test_transform(t, x; wrong_size = (4, 5))
    test_transform(t, randn(ComplexF64, 6, 5))
    test_transform(Modulate(2), randn(Float32, 7))
end

@testitem "defaults between call forms" tags = [:interface] setup = [ToyTransforms] begin
    using AbstractMultiscaleTransforms: DefaultWorkspace, check_workspace, signal_size
    using .ToyTransforms: Split, Haar
    t = Split(2)
    x = randn(4, 4)
    ws = make_workspace(t, x)
    @test ws isa DefaultWorkspace
    @test ws == make_workspace(t, Float64, (4, 4))
    @test ws == make_workspace(t, x; flags = 0, tasks = 2, tune = true, prewarm = true)
    @test_throws MethodError make_workspace(t, x; threads = 2)
    @test transform(ws) === t
    @test eltype(ws) === Float64
    @test size(ws) == (4, 4)
    @test sprint(show, ws) == "DefaultWorkspace($(sprint(show, t)), Float64, (4, 4))"
    @test nsubbands(t, (4, 4)) == 2
    @test_throws "not for $(Split(3))" check_workspace(ws, Split(3), Float64, (4, 4))
    @test_throws "element type Float64, not for Float32" check_workspace(ws, t, Float32, (4, 4))
    @test_throws "size (4, 4), not (4, 5)" check_workspace(ws, t, Float64, (4, 5))
    @test signal_size(t, analyze(t, x)) == (4, 4)
    h = Haar(1)
    c = analyze(h, randn(8))
    @test size(synthesize(h, c)) == (8,)          # size from the SubbandVector's layout
    @test !AbstractMultiscaleTransforms.supports_streaming(h)
    # The toy transforms' methods (e.g. `signal_size(::Split, ::AbstractArray)`)
    # must not be ambiguous with the interface's own.
    @test isempty(Test.detect_ambiguities(AbstractMultiscaleTransforms, ToyTransforms))
end

@testitem "preserves_real has no default" tags = [:interface] begin
    using AbstractMultiscaleTransforms: preserves_real
    struct Undeclared <: AbstractMultiscaleTransform end
    @test_throws ArgumentError preserves_real(Undeclared())
    @test_throws "Undeclared does not define `AbstractMultiscaleTransforms.preserves_real`" preserves_real(Undeclared())
end

@testitem "test_transform needs a transform and an array" begin
    using AbstractMultiscaleTransforms.Testing: test_transform
    @test_throws MethodError test_transform(1, 2)
end
