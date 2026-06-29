// aegis_image_util_260629.swift
// Added 260629: NSImage -> base64 JPEG data URI for Cerebras multimodal input.
// Downscales to maxDimension so the base64 payload stays well inside the 32K MCL.
// FAQ: only Base64 data URIs are accepted (hosted image URLs are not supported).
import AppKit

extension NSImage {
    func aegisJPEGDataURI(maxDimension: CGFloat, quality: CGFloat) -> String? {
        guard let tiff = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }

        let w = CGFloat(rep.pixelsWide), h = CGFloat(rep.pixelsHigh)
        guard w > 0, h > 0 else { return nil }

        let scale = min(1.0, maxDimension / max(w, h))
        let targetW = Int((w * scale).rounded())
        let targetH = Int((h * scale).rounded())

        guard let resized = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: targetW, pixelsHigh: targetH,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }

        resized.size = NSSize(width: targetW, height: targetH)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: resized)
        self.draw(in: NSRect(x: 0, y: 0, width: targetW, height: targetH))
        NSGraphicsContext.restoreGraphicsState()

        guard let jpeg = resized.representation(using: .jpeg,
                                                properties: [.compressionFactor: quality]) else { return nil }
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }
}
