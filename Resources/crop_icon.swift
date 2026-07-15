import Foundation
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else { exit(1) }
let inputPath = args[1]
let outputPath = args[2]

guard let nsImage = NSImage(contentsOfFile: inputPath) else { exit(1) }
guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(1) }

let width = cgImage.width
let height = cgImage.height
let colorSpace = CGColorSpaceCreateDeviceRGB()
var bitmapData = [UInt8](repeating: 0, count: width * height * 4)
let context = CGContext(data: &bitmapData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

var minX = width
var minY = height
var maxX = 0
var maxY = 0

for y in 0..<height {
    for x in 0..<width {
        let offset = (y * width + x) * 4
        let r = bitmapData[offset]
        let g = bitmapData[offset + 1]
        let b = bitmapData[offset + 2]
        
        // Background is white, so anything not purely white is part of the icon.
        // We use 245 to account for slight gradient/compression artifacts in white.
        if r < 245 || g < 245 || b < 245 {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
}

// Add a tiny bit of padding to the bounding box if we cropped too tight
let padding = 10
minX = max(0, minX - padding)
maxX = min(width, maxX + padding)
minY = max(0, minY - padding)
maxY = min(height, maxY + padding)

let cropWidth = maxX - minX
let cropHeight = maxY - minY
let size = max(cropWidth, cropHeight)
let midX = minX + cropWidth / 2
let midY = minY + cropHeight / 2
let cropRect = CGRect(x: max(0, midX - size / 2), y: max(0, midY - size / 2), width: size, height: size)

guard let croppedCGImage = cgImage.cropping(to: cropRect) else { exit(1) }

let outSize: CGFloat = 1024
let finalImage = NSImage(size: NSSize(width: outSize, height: outSize))
finalImage.lockFocus()

let rect = NSRect(x: 0, y: 0, width: outSize, height: outSize)
let path = NSBezierPath(roundedRect: rect, xRadius: outSize * 0.225, yRadius: outSize * 0.225)
path.addClip()

let croppedNSImage = NSImage(cgImage: croppedCGImage, size: NSSize(width: size, height: size))
croppedNSImage.draw(in: rect)

finalImage.unlockFocus()

if let tiffData = finalImage.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: outputPath))
}
