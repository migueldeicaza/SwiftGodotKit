This directory shows how you can use SwiftGodotKit in a standalone Swift Package.

This directory was initially created like this:

```bash
swift package init -n StandaloneExample
```

And then Package.swift was extended to reference SwiftGodotKit and the sample placed.

To run, do this:

```bash
$ cp .build/*/*/libgodot.dylib .
$ swift run
```

