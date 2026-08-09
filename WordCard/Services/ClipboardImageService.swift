import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ExtractedImageInfo {
    let data: Data
    let width: Double
    let height: Double
    let sourceDescription: String
}

enum ClipboardImageService {

    /// Checks if the system clipboard currently contains an image or image file URL.
    static func hasImageInClipboard() -> Bool {
        #if os(macOS)
        let pb = NSPasteboard.general
        if let types = pb.types {
            let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
            if types.contains(where: { imageTypes.contains($0) }) {
                return true
            }
            if types.contains(.fileURL),
               let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
               let first = urls.first {
                let ext = first.pathExtension.lowercased()
                return ["png", "jpg", "jpeg", "heic", "webp", "gif", "tiff"].contains(ext)
            }
        }
        return NSImage(pasteboard: pb) != nil
        #else
        let pb = UIPasteboard.general
        if pb.hasImages || pb.image != nil {
            return true
        }
        if let urls = pb.urls, let first = urls.first {
            let ext = first.pathExtension.lowercased()
            return ["png", "jpg", "jpeg", "heic", "webp", "gif", "tiff"].contains(ext)
        }
        return false
        #endif
    }

    /// Reads and extracts image data, dimensions, and source description from the clipboard.
    static func fetchImageFromClipboard() -> ExtractedImageInfo? {
        #if os(macOS)
        let pb = NSPasteboard.general

        // 1. Check direct file URLs on pasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstURL = urls.first {
            if let nsImage = NSImage(contentsOf: firstURL),
               let data = imageData(from: nsImage) {
                let size = nsImage.size
                let width = max(Double(size.width), 1.0)
                let height = max(Double(size.height), 1.0)
                return ExtractedImageInfo(
                    data: data,
                    width: width,
                    height: height,
                    sourceDescription: firstURL.lastPathComponent
                )
            }
        }

        // 2. Check NSImage from pasteboard
        if let nsImage = NSImage(pasteboard: pb),
           let data = imageData(from: nsImage) {
            let size = nsImage.size
            let width = max(Double(size.width), 1.0)
            let height = max(Double(size.height), 1.0)
            let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
            return ExtractedImageInfo(
                data: data,
                width: width,
                height: height,
                sourceDescription: "Pasted Image (\(timestamp))"
            )
        }

        return nil
        #else
        let pb = UIPasteboard.general

        // 1. Direct UIImage
        if let uiImage = pb.image,
           let data = uiImage.jpegData(compressionQuality: 0.9) ?? uiImage.pngData() {
            let size = uiImage.size
            let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
            return ExtractedImageInfo(
                data: data,
                width: max(Double(size.width), 1.0),
                height: max(Double(size.height), 1.0),
                sourceDescription: "Pasted Image (\(timestamp))"
            )
        }

        // 2. Check file URLs
        if let urls = pb.urls, let firstURL = urls.first,
           let data = try? Data(contentsOf: firstURL),
           let uiImage = UIImage(data: data) {
            let size = uiImage.size
            return ExtractedImageInfo(
                data: data,
                width: max(Double(size.width), 1.0),
                height: max(Double(size.height), 1.0),
                sourceDescription: firstURL.lastPathComponent
            )
        }

        return nil
        #endif
    }

    /// Process raw image data from drop or file picker to get dimensions and optimized data.
    static func processImageData(_ rawData: Data, filename: String? = nil) -> ExtractedImageInfo? {
        #if os(macOS)
        guard let nsImage = NSImage(data: rawData),
              let optimizedData = imageData(from: nsImage) else { return nil }
        let size = nsImage.size
        let title = filename ?? "Imported Image (\(Date().formatted(date: .abbreviated, time: .shortened)))"
        return ExtractedImageInfo(
            data: optimizedData,
            width: max(Double(size.width), 1.0),
            height: max(Double(size.height), 1.0),
            sourceDescription: title
        )
        #else
        guard let uiImage = UIImage(data: rawData),
              let optimizedData = uiImage.jpegData(compressionQuality: 0.9) ?? uiImage.pngData() else { return nil }
        let size = uiImage.size
        let title = filename ?? "Imported Image (\(Date().formatted(date: .abbreviated, time: .shortened)))"
        return ExtractedImageInfo(
            data: optimizedData,
            width: max(Double(size.width), 1.0),
            height: max(Double(size.height), 1.0),
            sourceDescription: title
        )
        #endif
    }

    #if os(macOS)
    private static func imageData(from image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) ?? bitmapRep.representation(using: .png, properties: [:])
    }
    #endif

    /// Copies an image card's data back to the system clipboard.
    static func copyToClipboard(imageData: Data) {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        if let image = NSImage(data: imageData) {
            pb.writeObjects([image])
        }
        #else
        if let image = UIImage(data: imageData) {
            UIPasteboard.general.image = image
        }
        #endif
    }
}
