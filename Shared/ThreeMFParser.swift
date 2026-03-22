import Foundation
import simd
import ZIPFoundation

enum ThreeMFError: Error, LocalizedError {
    case invalidArchive
    case entryNotFound(String)
    case xmlParseFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArchive: return "Could not open 3MF archive"
        case .entryNotFound(let path): return "Entry not found in archive: \(path)"
        case .xmlParseFailed(let msg): return "XML parsing failed: \(msg)"
        }
    }
}

struct ThreeMFParser {

    func parse(url: URL) throws -> ThreeMFModel {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw ThreeMFError.invalidArchive
        }

        let modelPath = findModelPath(in: archive)
        let modelData = try extractData(path: modelPath, from: archive)

        let xmlDelegate = ModelXMLDelegate()
        let parser = XMLParser(data: modelData)
        parser.delegate = xmlDelegate
        guard parser.parse() else {
            throw ThreeMFError.xmlParseFailed(
                parser.parserError?.localizedDescription ?? "Unknown error"
            )
        }

        var allObjects = xmlDelegate.objects

        // Handle multi-file 3MF (Bambu Studio / OrcaSlicer)
        let externalPaths = collectExternalPaths(from: allObjects)
        for extPath in externalPaths {
            let cleanPath = extPath.hasPrefix("/") ? String(extPath.dropFirst()) : extPath
            guard let data = try? extractData(path: cleanPath, from: archive) else { continue }

            let extDelegate = ModelXMLDelegate()
            let extParser = XMLParser(data: data)
            extParser.delegate = extDelegate
            guard extParser.parse() else { continue }

            // Store external objects with path-prefixed keys
            for (id, obj) in extDelegate.objects {
                allObjects["\(extPath)#\(id)"] = obj
            }
        }

        // Resolve component path references to path-prefixed keys
        for (id, obj) in allObjects {
            var updated = obj
            updated.components = obj.components.map { comp in
                guard let path = comp.path else { return comp }
                var resolved = comp
                resolved.objectId = "\(path)#\(comp.objectId)"
                resolved.path = nil
                return resolved
            }
            allObjects[id] = updated
        }

        return ThreeMFModel(objects: allObjects, buildItems: xmlDelegate.buildItems)
    }

    // MARK: - Thumbnail extraction

    static func extractThumbnail(from url: URL) -> Data? {
        guard let archive = try? Archive(url: url, accessMode: .read) else { return nil }

        let paths = [
            "Metadata/plate_1.png",
            "Metadata/thumbnail.png",
            "Metadata/Thumbnail/thumbnail.png",
            "Auxiliaries/.thumbnails/thumbnail_middle.png",
            "Auxiliaries/.thumbnails/thumbnail_3mf.png",
            ".thumbnail/thumbnail.png",
        ]

        for path in paths {
            if let entry = archive[path] {
                var data = Data()
                do {
                    _ = try archive.extract(entry) { data.append($0) }
                    if !data.isEmpty { return data }
                } catch {
                    continue
                }
            }
        }

        // Check _rels/.rels for thumbnail relationship
        if let relsEntry = archive["_rels/.rels"],
           let relsData = try? {
               var d = Data()
               _ = try archive.extract(relsEntry) { d.append($0) }
               return d
           }() {
            let relsDelegate = RelsXMLDelegate()
            let parser = XMLParser(data: relsData)
            parser.delegate = relsDelegate
            if parser.parse(), let thumbPath = relsDelegate.thumbnailPath {
                let clean = thumbPath.hasPrefix("/") ? String(thumbPath.dropFirst()) : thumbPath
                if let entry = archive[clean] {
                    var data = Data()
                    _ = try? archive.extract(entry) { data.append($0) }
                    if !data.isEmpty { return data }
                }
            }
        }

        return nil
    }

    // MARK: - Private helpers

    private func findModelPath(in archive: Archive) -> String {
        if let relsEntry = archive["_rels/.rels"],
           let relsData = try? {
               var d = Data()
               _ = try archive.extract(relsEntry) { d.append($0) }
               return d
           }() {
            let relsDelegate = RelsXMLDelegate()
            let parser = XMLParser(data: relsData)
            parser.delegate = relsDelegate
            if parser.parse(), let path = relsDelegate.modelPath {
                return path.hasPrefix("/") ? String(path.dropFirst()) : path
            }
        }
        return "3D/3dmodel.model"
    }

    private func extractData(path: String, from archive: Archive) throws -> Data {
        guard let entry = archive[path] else {
            throw ThreeMFError.entryNotFound(path)
        }
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return data
    }

    private func collectExternalPaths(from objects: [String: ThreeMFObject]) -> Set<String> {
        var paths = Set<String>()
        for obj in objects.values {
            for comp in obj.components {
                if let path = comp.path {
                    paths.insert(path)
                }
            }
        }
        return paths
    }
}

// MARK: - _rels/.rels XML delegate

private class RelsXMLDelegate: NSObject, XMLParserDelegate {
    var modelPath: String?
    var thumbnailPath: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "Relationship" else { return }
        let type = attributeDict["Type"] ?? ""
        if type.contains("3dmodel") {
            modelPath = attributeDict["Target"]
        } else if type.contains("thumbnail") {
            thumbnailPath = attributeDict["Target"]
        }
    }
}

// MARK: - 3D model XML delegate

private class ModelXMLDelegate: NSObject, XMLParserDelegate {
    var objects: [String: ThreeMFObject] = [:]
    var buildItems: [ThreeMFBuildItem] = []

    private var currentObject: ThreeMFObject?
    private var currentVertices: [SIMD3<Float>] = []
    private var currentTriangles: [(Int, Int, Int)] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "object":
            currentObject = ThreeMFObject(id: attributeDict["id"] ?? "")

        case "mesh":
            currentVertices = []
            currentTriangles = []

        case "vertex":
            if let x = Float(attributeDict["x"] ?? ""),
               let y = Float(attributeDict["y"] ?? ""),
               let z = Float(attributeDict["z"] ?? "") {
                currentVertices.append(SIMD3(x, y, z))
            }

        case "triangle":
            if let v1 = Int(attributeDict["v1"] ?? ""),
               let v2 = Int(attributeDict["v2"] ?? ""),
               let v3 = Int(attributeDict["v3"] ?? "") {
                currentTriangles.append((v1, v2, v3))
            }

        case "component":
            let objId = attributeDict["objectid"] ?? ""
            let transform = attributeDict["transform"].flatMap(Self.parseTransform)
            // Bambu/OrcaSlicer use p:path for multi-file references
            let path = attributeDict["p:path"]
            currentObject?.components.append(
                ThreeMFComponent(objectId: objId, transform: transform, path: path)
            )

        case "item":
            let objId = attributeDict["objectid"] ?? ""
            let transform = attributeDict["transform"].flatMap(Self.parseTransform)
            buildItems.append(ThreeMFBuildItem(objectId: objId, transform: transform))

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        switch elementName {
        case "mesh":
            currentObject?.mesh = ThreeMFMesh(
                vertices: currentVertices,
                triangles: currentTriangles
            )
        case "object":
            if let obj = currentObject {
                objects[obj.id] = obj
            }
            currentObject = nil
        default:
            break
        }
    }

    // 3MF transform: 12 values (3x4 row-major, row-vector convention)
    // Convert to simd_float4x4 (column-major, column-vector convention) by transposing
    static func parseTransform(_ string: String) -> simd_float4x4? {
        let v = string.split(separator: " ").compactMap { Float($0) }
        guard v.count == 12 else { return nil }
        return simd_float4x4(
            SIMD4(v[0], v[1], v[2], 0),    // column 0
            SIMD4(v[3], v[4], v[5], 0),    // column 1
            SIMD4(v[6], v[7], v[8], 0),    // column 2
            SIMD4(v[9], v[10], v[11], 1)   // column 3 (translation)
        )
    }
}
