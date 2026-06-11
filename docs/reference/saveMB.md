# Save a modelblueprint to disk

Serialises a `modelblueprint` to a compressed `.tar.gz` archive
containing all components needed to fully reconstruct it: model, data
splits, pipeline functions, and metadata.

## Usage

``` r
saveMB(object, path = getwd(), filename = NULL, ...)
```

## Arguments

- object:

  A `modelblueprint` object.

- path:

  Directory to write the archive to. Default: working directory.

- filename:

  Optional filename. When `NULL`, `model_display_name` is used.

- ...:

  Currently unused. Reserved for future subclass methods.

## Value

Invisibly returns the full normalised path to the saved archive.

## See also

[`loadMB()`](loadMB.md)
