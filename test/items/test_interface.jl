@testitem "conformance: stacked toy transform" tags = [:interface] setup = [ToyTransforms] begin
    using MultiscaleTransformsBase.Testing: test_transform
    using .ToyTransforms: Split
    test_transform(Split(3), randn(8, 6); wrong_size = (4, 6))
    test_transform(Split(2), randn(ComplexF64, 5, 4, 3); exact_real_linear = true)
    test_transform(Split(1), randn(Float32, 7))
end

@testitem "conformance: ragged toy transform" tags = [:interface] setup = [ToyTransforms] begin
    using MultiscaleTransformsBase.Testing: test_transform
    using .ToyTransforms: Haar
    test_transform(Haar(3), randn(32); wrong_size = (16,))
    test_transform(Haar(2), randn(ComplexF64, 16); exact_real_linear = true)
end

@testitem "defaults between call forms" tags = [:interface] setup = [ToyTransforms] begin
    using MultiscaleTransformsBase: DefaultWorkspace, check_workspace, signal_size
    using .ToyTransforms: Split, Haar
    t = Split(2)
    x = randn(4, 4)
    ws = make_workspace(t, x)
    @test ws isa DefaultWorkspace
    @test ws == make_workspace(t, Float64, (4, 4))
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
    @test !MultiscaleTransformsBase.supports_streaming(h)
    # The toy transforms' methods (e.g. `signal_size(::Split, ::AbstractArray)`)
    # must not be ambiguous with the interface's own.
    @test isempty(Test.detect_ambiguities(MultiscaleTransformsBase, ToyTransforms))
end
