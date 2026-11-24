// Draws the Second Calendar app icon at any pixel size.
//   swift Scripts/icon/draw-icon.swift <size> <out.png>
// Same family as TidyGrid, TextExhibit and SendSize: warm-white macOS body, ink shapes, one sunflower piece.
// Two calendar sheets: a grey one behind (the colleagues' calendar) and an ink one in front with a
// sunflower header; one day on its grid is lit sunflower. Coordinates are on the 1024 grid, y down.
import AppKit

let args = CommandLine.arguments
let px = CGFloat(Int(args[1])!)
let out = args[2]

let ink = CGColor(srgbRed: 0x12 / 255, green: 0x12 / 255, blue: 0x12 / 255, alpha: 1)
let sun = CGColor(srgbRed: 1, green: 0xD2 / 255, blue: 0x33 / 255, alpha: 1)
let body = CGColor(srgbRed: 0xF8 / 255, green: 0xF7 / 255, blue: 0xF5 / 255, alpha: 1)
let back = CGColor(srgbRed: 0xC9 / 255, green: 0xC5 / 255, blue: 0xBE / 255, alpha: 1)
let paper = CGColor(srgbRed: 0xF8 / 255, green: 0xF7 / 255, blue: 0xF5 / 255, alpha: 0.9)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
ctx.scaleBy(x: px / 1024, y: px / 1024)
ctx.translateBy(x: 0, y: 1024); ctx.scaleBy(x: 1, y: -1)

func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}
func fill(_ p: CGPath, _ c: CGColor) { ctx.addPath(p); ctx.setFillColor(c); ctx.fillPath() }

// Body with the family's soft drop shadow.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 28, color: CGColor(gray: 0, alpha: 0.22))
fill(rr(100, 100, 824, 824, 185), body)
ctx.restoreGState()

// Back sheet, tilted a little.
ctx.saveGState()
ctx.translateBy(x: 560, y: 470); ctx.rotate(by: 8 * .pi / 180)
fill(rr(-250, -250, 500, 470, 70), back)
ctx.restoreGState()

// Front sheet: ink body, sunflower header band.
let fx: CGFloat = 230, fy: CGFloat = 330, fw: CGFloat = 500, fh: CGFloat = 470
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 8), blur: 18, color: CGColor(gray: 0, alpha: 0.18))
fill(rr(fx, fy, fw, fh, 70), ink)
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(rr(fx, fy, fw, fh, 70)); ctx.clip()
fill(CGPath(rect: CGRect(x: fx, y: fy, width: fw, height: 120), transform: nil), sun)
ctx.restoreGState()
// Binder rings.
for x in [fx + 140, fx + fw - 140] {
    fill(rr(x - 18, fy - 40, 36, 90, 18), ink)
}
// Day grid: 4 × 3, one lit.
let cols = 4, rows = 3
let gx = fx + 62, gy = fy + 170, cell: CGFloat = 68, gap: CGFloat = 30
for r in 0..<rows {
    for c in 0..<cols {
        let x = gx + CGFloat(c) * (cell + gap), y = gy + CGFloat(r) * (cell + gap)
        fill(rr(x, y, cell, cell, 18), (r == 1 && c == 2) ? sun : paper)
    }
}

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
