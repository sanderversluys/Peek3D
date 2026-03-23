# Peek3D

A macOS Quick Look extension for 3D printing files. Press Space in Finder to get an interactive 3D preview of your models.

## Features

- **Quick Look preview** — select any STL, OBJ, or 3MF file in Finder and press Space
- **Interactive 3D** — drag to orbit, scroll to zoom, with slow turntable rotation
- **3MF support** — full support including Bambu Studio and OrcaSlicer multi-file projects
- **Fast thumbnails** — extracts embedded PNGs from 3MF files for instant thumbnails
- **Lightweight** — runs as a Quick Look extension, no heavy app needed

## Supported Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| STL | `.stl` | Standard Tessellation Language |
| OBJ | `.obj` | Wavefront OBJ |
| 3MF | `.3mf` | 3D Manufacturing Format |

## Install

### Download

Get the latest release from [GitHub Releases](https://github.com/sanderversluys/Peek3D/releases) or the [Mac App Store](#).

1. Download `Peek3D.dmg`
2. Drag Peek3D to Applications
3. Launch once to register the extensions
4. Select any 3D file in Finder and press Space

### Build from source

Requires macOS 15.0+ and Xcode 16+.

```bash
# Install xcodegen if needed
brew install xcodegen

# Generate Xcode project and build
xcodegen generate
xcodebuild -project Peek3D.xcodeproj -scheme Peek3D -configuration Release build
```

## Architecture

```
Peek3D/                    Host app (registers extensions + UTIs)
PreviewExtension/          Quick Look Preview (SCNView + interactive 3D)
ThumbnailExtension/        Quick Look Thumbnail (embedded PNG or SCNRenderer)
Shared/
├── ModelLoader.swift      Dispatch: STL/OBJ → ModelIO, 3MF → custom parser
├── ThreeMFParser.swift    ZIP extraction + SAX XML parsing
├── ThreeMFModel.swift     Data model structs
├── SceneBuilder.swift     ThreeMFModel → SCNGeometry with computed normals
└── SceneConfigurator.swift Camera, lighting, model framing
```

## Dependencies

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) — pure Swift ZIP library (MIT)

## License

[MIT](LICENSE)

## Author

[Sander Versluys](https://sanderversluys.com)
