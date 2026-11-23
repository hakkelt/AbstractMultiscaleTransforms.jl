@testmodule ToyTransforms begin
    using AbstractMultiscaleTransforms
    using AbstractMultiscaleTransforms: check_workspace, DefaultWorkspace
    import AbstractMultiscaleTransforms: analyze!, synthesize!, similar_coefficients, subband_layout, subband,
        supports_streaming, analyze, make_workspace, signal_size

    # `n` equal subbands, each `x / n`, stacked along a trailing axis; the
    # synthesis sums them.  A stacked transform without a workspace of its own.
    struct Split <: AbstractMultiscaleTransform
        n::Int
    end

    similar_coefficients(t::Split, x::AbstractArray) = similar(x, float(eltype(x)), (size(x)..., t.n))
    subband_layout(t::Split, dims::Dims) = collect(1:t.n)
    subband(::Split, c::AbstractArray, i::Integer) = selectdim(c, ndims(c), i)
    signal_size(::Split, c::AbstractArray) = size(c)[1:(end - 1)]
    supports_streaming(::Split) = true

    function _check(workspace, t, x)
        workspace === nothing || check_workspace(workspace, t, eltype(x), size(x))
        return nothing
    end

    function analyze!(c::AbstractArray, t::Split, x::AbstractArray; workspace = nothing, threaded = nothing)
        _check(workspace, t, x)
        size(c) == (size(x)..., t.n) || throw(DimensionMismatch("coefficients of size $(size(c)) do not fit"))
        for i in 1:t.n
            subband(t, c, i) .= x ./ t.n
        end
        return c
    end

    function synthesize!(x::AbstractArray, t::Split, c::AbstractArray; workspace = nothing, threaded = nothing)
        _check(workspace, t, x)
        x .= dropdims(sum(c; dims = ndims(c)); dims = ndims(c))
        return x
    end

    function analyze(f, t::Split, x::AbstractArray; workspace = nothing, threaded = nothing)
        _check(workspace, t, x)
        band = x ./ t.n
        for i in 1:t.n
            f(i, band)
        end
        return nothing
    end

    function synthesize!(f, x::AbstractArray, t::Split; workspace = nothing, threaded = nothing)
        _check(workspace, t, x)
        fill!(x, zero(eltype(x)))
        for i in 1:t.n
            x .+= f(i)
        end
        return x
    end

    # An orthonormal 1-D Haar transform with `levels` levels, whose subbands
    # (lowpass, then details from coarse to fine) halve in length: a ragged
    # transform with SubbandVector coefficients.
    struct Haar <: AbstractMultiscaleTransform
        levels::Int
    end

    function _haar_layout(t::Haar, dims::Dims{1})
        n = dims[1]
        n % 2^t.levels == 0 || throw(DimensionMismatch("length $(n) is not divisible by 2^$(t.levels)"))
        sizes = [(n >> t.levels,); [(n >> l,) for l in t.levels:-1:1]]
        return SubbandLayout(sizes, dims)
    end

    subband_layout(t::Haar, dims::Dims{1}) = _haar_layout(t, dims).sizes
    similar_coefficients(t::Haar, x::AbstractVector) =
        SubbandVector{float(eltype(x))}(undef, _haar_layout(t, size(x)), x)
    subband(::Haar, c::SubbandVector, i::Integer) = subband(c, i)

    function analyze!(c::SubbandVector, t::Haar, x::AbstractVector; workspace = nothing, threaded = nothing)
        _check(workspace, t, x)
        c.layout == _haar_layout(t, size(x)) || throw(DimensionMismatch("coefficients do not fit"))
        a = float.(x)
        for l in 1:t.levels
            ev, od = a[1:2:end], a[2:2:end]
            subband(c, t.levels + 2 - l) .= (ev .- od) ./ sqrt(2)
            a = (ev .+ od) ./ sqrt(2)
        end
        subband(c, 1) .= a
        return c
    end

    function synthesize!(x::AbstractVector, t::Haar, c::SubbandVector; workspace = nothing, threaded = nothing)
        _check(workspace, t, x)
        a = copy(subband(c, 1))
        for l in t.levels:-1:1
            d = subband(c, t.levels + 2 - l)
            b = similar(a, 2 * length(a))
            b[1:2:end] .= (a .+ d) ./ sqrt(2)
            b[2:2:end] .= (a .- d) ./ sqrt(2)
            a = b
        end
        x .= a
        return x
    end
end
