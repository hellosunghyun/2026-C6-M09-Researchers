import CoreTransferable
import Foundation
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

nonisolated struct ImportedProtocolInput: Identifiable, Equatable, Sendable, Transferable {
    let id: UUID
    let url: URL
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            try copyOwned(received.file, useSecurityScope: false)
        }
    }

    static func copyFile(_ source: URL) async throws -> Self {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try copyOwned(source, useSecurityScope: true))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func copyOwned(_ source: URL, useSecurityScope: Bool) throws -> Self {
        let id = UUID()
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent("labcord-protocol-\(id.uuidString)")
            .appendingPathExtension(source.pathExtension)
        let scoped = useSecurityScope && source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: source, to: target)
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
        return Self(id: id, url: target, name: source.lastPathComponent)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

struct ProtocolPhotoThumbnail: View {
    let url: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail).resizable().scaledToFill()
            } else {
                ProgressView()
            }
        }
        .accessibilityLabel("선택한 사진")
        .task(id: url) {
            thumbnail = await Self.loadThumbnail(url)
        }
    }

    private static func loadThumbnail(_ url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 300
                ]
                let source = CGImageSourceCreateWithURL(url as CFURL, nil)
                let image = source.flatMap {
                    CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary)
                }
                continuation.resume(returning: image.map { UIImage(cgImage: $0) })
            }
        }
    }
}
