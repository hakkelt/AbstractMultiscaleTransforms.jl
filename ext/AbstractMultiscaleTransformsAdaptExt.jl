module AbstractMultiscaleTransformsAdaptExt

using AbstractMultiscaleTransforms: SubbandVector
using Adapt: Adapt

Adapt.adapt_structure(to, c::SubbandVector) = SubbandVector(Adapt.adapt(to, c.data), c.layout)

end # module
