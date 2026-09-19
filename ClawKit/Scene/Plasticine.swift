import RealityKit
import UIKit

/// A soft, matte material with fingerprints, like modelling clay.
enum Plasticine {
    static func material(_ color: UIColor, roughness: Float = 0.78) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = 0.0
        material.specular = 0.35
        material.sheen = .init(tint: color.withAlphaComponent(1).lighter)
        if let fingerprints {
            material.normal = .init(texture: .init(fingerprints))
        }
        return material
    }

    /// A shiny material for the parts that aren't clay: glass and chrome.
    static func glossy(_ color: UIColor, metallic: Float = 0) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = 0.2
        material.metallic = .init(floatLiteral: metallic)
        return material
    }

    /// A tiling normal map with smooth dents, generated once.
    private static let fingerprints: TextureResource? = {
        let size = 128
        let heights = smoothNoise(size: size, cells: 8)
        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        let strength: Float = 2.5
        for y in 0..<size {
            for x in 0..<size {
                let left = heights[y * size + (x + size - 1) % size]
                let right = heights[y * size + (x + 1) % size]
                let up = heights[((y + size - 1) % size) * size + x]
                let down = heights[((y + 1) % size) * size + x]
                let normal = simd_normalize(SIMD3<Float>((left - right) * strength, (up - down) * strength, 1))
                let index = (y * size + x) * 4
                pixels[index] = UInt8((normal.x * 0.5 + 0.5) * 255)
                pixels[index + 1] = UInt8((normal.y * 0.5 + 0.5) * 255)
                pixels[index + 2] = UInt8((normal.z * 0.5 + 0.5) * 255)
            }
        }
        guard
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let image = CGImage(
                width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
            )
        else { return nil }
        return try? TextureResource(image: image, options: .init(semantic: .normal))
    }()

    /// Tiling value noise with smooth interpolation, in 0...1.
    private static func smoothNoise(size: Int, cells: Int) -> [Float] {
        var generator = SystemRandomNumberGenerator()
        let lattice = (0..<(cells * cells)).map { _ in Float.random(in: 0...1, using: &generator) }
        func value(_ x: Int, _ y: Int) -> Float {
            lattice[((y % cells + cells) % cells) * cells + (x % cells + cells) % cells]
        }
        var result = [Float](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let fx = Float(x) / Float(size) * Float(cells)
                let fy = Float(y) / Float(size) * Float(cells)
                let ix = Int(fx), iy = Int(fy)
                let tx = smoothstep(fx - Float(ix)), ty = smoothstep(fy - Float(iy))
                let top = value(ix, iy) * (1 - tx) + value(ix + 1, iy) * tx
                let bottom = value(ix, iy + 1) * (1 - tx) + value(ix + 1, iy + 1) * tx
                result[y * size + x] = top * (1 - ty) + bottom * ty
            }
        }
        return result
    }

    private static func smoothstep(_ t: Float) -> Float {
        t * t * (3 - 2 * t)
    }
}

extension UIColor {
    var lighter: UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return UIColor(hue: hue, saturation: saturation * 0.6, brightness: min(brightness * 1.2, 1), alpha: alpha)
    }

    var darker: UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return UIColor(hue: hue, saturation: saturation, brightness: brightness * 0.7, alpha: alpha)
    }
}
