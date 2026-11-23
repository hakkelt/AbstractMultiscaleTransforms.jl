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

@testitem "Code complexity" tags = [:quality] begin
    using CodeComplexity
    # No definition in src/ or ext/ may exceed these limits: CodeComplexity's
    # defaults (10 and 15), or the package's most complex definition where that
    # is higher.
    root = pkgdir(MultiscaleTransformsBase)
    dirs = filter(isdir, joinpath.(root, ("src", "ext")))
    for (metric, limit) in ((CyclomaticComplexity(), 10), (CognitiveComplexity(), 15))
        over = [
            (relpath(f.path, root), m.line, m.name, m.value)
                for dir in dirs for f in measure_directory(metric, dir; recursive = true)
                for m in f.functions if m.value > limit
        ]
        @test isempty(over)
    end
end
