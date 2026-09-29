# Standalone example

This Swift package uses the local SwiftGodot and SwiftGodotKit 4.7 checkouts.
Build the libgodot XCFrameworks first from `SwiftGodotKit/scripts`:

```sh
make release-payloads
```

Then build and run the macOS example:

```sh
swift run --package-path StandaloneExample StandaloneExample
```

The app creates its scene in Swift and does not need a game pack.
