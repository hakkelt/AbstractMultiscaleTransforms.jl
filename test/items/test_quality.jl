@testitem "Aqua" tags = [:quality] begin
    using Aqua
    Aqua.test_all(MultiscaleTransformsBase)
end

@testitem "ExplicitImports" tags = [:quality] begin
    using ExplicitImports
    @test check_no_implicit_imports(MultiscaleTransformsBase) === nothing
    @test check_no_stale_explicit_imports(MultiscaleTransformsBase) === nothing
    @test check_all_explicit_imports_via_owners(MultiscaleTransformsBase) === nothing
    @test check_all_qualified_accesses_via_owners(MultiscaleTransformsBase) === nothing
    @test check_no_self_qualified_accesses(MultiscaleTransformsBase) === nothing
end
