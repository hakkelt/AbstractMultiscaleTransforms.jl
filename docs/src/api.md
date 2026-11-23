# API reference

Every public name of AbstractMultiscaleTransforms. Names listed with the
`AbstractMultiscaleTransforms.` prefix are public but not exported.

```@docs
AbstractMultiscaleTransforms
```

## Transforms and verbs

```@docs
AbstractMultiscaleTransform
analyze
analyze!
synthesize
synthesize!
```

## Workspaces

```@docs
AbstractTransformWorkspace
make_workspace
transform
AbstractMultiscaleTransforms.DefaultWorkspace
AbstractMultiscaleTransforms.check_workspace
```

## Coefficients

```@docs
similar_coefficients
subband_layout
nsubbands
subband
AbstractMultiscaleTransforms.signal_size
SubbandVector
SubbandLayout
```

## Streaming

```@docs
AbstractMultiscaleTransforms.supports_streaming
```

## Conformance tests

```@docs
AbstractMultiscaleTransforms.Testing
AbstractMultiscaleTransforms.Testing.test_transform
```
