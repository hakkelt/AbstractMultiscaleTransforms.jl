# The interface's extension points (`subband_layout`, `similar_coefficients`, ...) have
# no method for the abstract type, so `report_package` flags every generic
# entry point as a missing method. The calls are analyzed with concrete
# transforms instead.
@testitem "JET: interface calls on toy transforms" tags = [:jet] setup = [ToyTransforms] begin
    using JET
    using .ToyTransforms: Split, Haar, Modulate
    mods = (AbstractMultiscaleTransforms,)
    for (t, x) in ((Split(2), randn(4, 4)), (Modulate(2), randn(4, 4)), (Haar(2), randn(8)))
        ws = make_workspace(t, x)
        c = analyze(t, x)
        @test_call target_modules = mods analyze(t, x)
        @test_call target_modules = mods analyze(t, x; workspace = ws)
        @test_call target_modules = mods synthesize(t, c)
        @test_call target_modules = mods synthesize(t, c; workspace = ws)
        @test_call target_modules = mods make_workspace(t, x)
        @test_call target_modules = mods nsubbands(t, size(x))
        @test_opt target_modules = mods analyze(t, x; workspace = ws)
        @test_opt target_modules = mods synthesize(t, c; workspace = ws)
    end
end
