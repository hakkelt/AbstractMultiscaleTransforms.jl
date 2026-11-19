# API Reference

```@docs
MultiscaleTransformsBase
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
MultiscaleTransformsBase.DefaultWorkspace
MultiscaleTransformsBase.check_workspace
```

## Coefficients

```@docs
similar_coefficients
subband_layout
nsubbands
subband
MultiscaleTransformsBase.signal_size
SubbandVector
SubbandLayout
```

## Streaming

```@docs
MultiscaleTransformsBase.supports_streaming
```

## Conformance tests

```@docs
MultiscaleTransformsBase.Testing
MultiscaleTransformsBase.Testing.test_transform
```
