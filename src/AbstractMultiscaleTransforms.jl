"""
    AbstractMultiscaleTransforms

The interface shared by multiscale transform packages (contourlets, surfacelets,
shearlets, wavelets, ...): transform objects, the verbs [`analyze`](@ref) and
[`synthesize`](@ref), reusable workspaces, and subband access on array-valued
coefficients.  It defines no transform of its own.

A package implementing a transform depends on this one, subtypes
[`AbstractMultiscaleTransform`](@ref), adds methods to the verbs and accessors,
re-exports them, and checks its types with
[`AbstractMultiscaleTransforms.Testing.test_transform`](@ref).
"""
module AbstractMultiscaleTransforms

using Compat: @compat
using LinearAlgebra: LinearAlgebra

export AbstractMultiscaleTransform, AbstractTransformWorkspace,
    analyze, analyze!, synthesize, synthesize!,
    make_workspace, transform, similar_coefficients,
    subband_layout, nsubbands, subband, SubbandVector, SubbandLayout

@compat public DefaultWorkspace, check_workspace, supports_streaming, signal_size, Testing

include("interface.jl")
include("workspace.jl")
include("subband_vector.jl")
include("testing.jl")

end # module
