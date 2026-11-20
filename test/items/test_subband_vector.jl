@testitem "SubbandLayout" tags = [:subbands] begin
    l = SubbandLayout([(2, 2), (4, 3)], (4, 4))
    @test length(l) == 16
    @test l == SubbandLayout([(2, 2), (4, 3)], (4, 4))
    @test hash(l) == hash(SubbandLayout([(2, 2), (4, 3)], (4, 4)))
    @test l != SubbandLayout([(2, 2), (3, 4)], (4, 4))
    @test nsubbands(l) == 2
    @test_throws "at least one subband" SubbandLayout(NTuple{2, Int}[], (4, 4))
    @test_throws "nonnegative" SubbandLayout([(2, -1)], (4, 4))
end

@testitem "SubbandVector on the host" tags = [:subbands] begin
    using LinearAlgebra: dot, norm, axpy!, axpby!, rmul!, lmul!
    l = SubbandLayout([(2, 2), (3, 4)], (4, 4))
    c = SubbandVector(collect(1.0:16.0), l)
    @test_throws "holds 16 coefficients, the data 15" SubbandVector(zeros(15), l)
    @test nsubbands(c) == 2
    @test subband(c, 1) == [1.0 3.0; 2.0 4.0]
    @test size(subband(c, 2)) == (3, 4)
    subband(c, 2)[1] = -5.0
    @test c[5] == -5.0
    c[5] = 5.0
    @test parent(c) === c.data

    d = 2 .* c .+ 1
    @test d isa SubbandVector{Float64}
    @test d.layout === l
    @test d == SubbandVector(2 .* (1.0:16.0) .+ 1, l)
    d .= c .- d
    @test d == SubbandVector(-(1.0:16.0) .- 1, l)
    e = c .+ collect(1.0:16.0)                # a plain vector of the same length
    @test e isa SubbandVector && e.data == 2 .* (1.0:16.0)
    z = c .* im
    @test z isa SubbandVector{ComplexF64}
    v = zeros(16)
    v .= c .* 2                               # into a plain array
    @test v == 2 .* (1.0:16.0)

    other = SubbandVector(collect(1.0:16.0), SubbandLayout([(4, 4)], (4, 4)))
    @test c != other
    @test_throws "different subband layouts" c .+ other
    @test_throws "different subband layouts" copyto!(similar(c), other)
    @test_throws "different subband layouts" dot(c, other)

    s = similar(c)
    @test s isa SubbandVector{Float64} && s.layout === l
    @test similar(c, Float32).data isa Vector{Float32}
    @test similar(c, Float32, (2, 3)) isa Matrix{Float32}
    @test copyto!(s, c) == c
    @test copy(c) == c && copy(c).data !== c.data
    @test zero(c) == SubbandVector(zeros(16), l)
    @test fill!(s, 2.0).data == fill(2.0, 16)
    @test isapprox(c, c .+ 1.0e-12)
    @test !isapprox(c, c .+ 1)
    @test sum(c) == sum(1.0:16.0)
    @test maximum(abs, c) == 16.0
    @test dot(c, c) == sum(abs2, 1.0:16.0)
    @test norm(c) ≈ sqrt(sum(abs2, 1.0:16.0))
    @test norm(c, 1) == sum(1.0:16.0)
    y = copy(c)
    @test axpy!(2.0, c, y) === y && y == 3 .* c
    @test axpby!(1.0, c, 2.0, y) === y && y == 7 .* c
    @test rmul!(y, 0.5) === y && y == 3.5 .* c
    @test lmul!(2.0, y) === y && y == 7 .* c
    @test sprint(show, MIME("text/plain"), c) == "16-element SubbandVector{Float64} with 2 subbands of Vector{Float64}"
    @test SubbandVector{Float32}(undef, l, zeros(1)) isa SubbandVector{Float32, Vector{Float32}}
end

@testitem "SubbandVector without scalar indexing" tags = [:subbands] begin
    using JLArrays: JLArray, JLArrays
    using Adapt: adapt
    using LinearAlgebra: dot, norm, axpy!
    JLArrays.allowscalar(false)
    l = SubbandLayout([(2, 2), (3, 4)], (4, 4))
    host = SubbandVector(collect(1.0:16.0), l)
    c = adapt(JLArray, host)
    @test c.data isa JLArray
    d = 2 .* c .+ 1
    @test d isa SubbandVector && d.data isa JLArray
    d .= d .- c
    @test Array(d.data) == (1.0:16.0) .+ 1
    @test sum(c) == sum(1.0:16.0)
    @test dot(c, c) == sum(abs2, 1.0:16.0)
    @test norm(c) ≈ norm(1.0:16.0)
    @test c == adapt(JLArray, host)
    @test axpy!(1.0, c, d) === d
    @test Array(subband(c, 1)) == [1.0 3.0; 2.0 4.0]
    @test Array(c) == collect(1.0:16.0)
    @test Vector(c) == collect(1.0:16.0)
    @test collect(c) == collect(1.0:16.0)
    @test similar(c).data isa JLArray
    @test copyto!(similar(c), c) == c
    @test fill!(similar(c), 0.0) == adapt(JLArray, SubbandVector(zeros(16), l))
end
