import AppKit
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 200, yRadius: 200).fill()
let symbol = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Fixdock")!.withSymbolConfiguration(.init(pointSize: 500, weight: .regular))!
symbol.isTemplate = false
let whiteSymbol = symbol.withSymbolConfiguration(.init(paletteColors: [.white]))!
whiteSymbol.draw(in: NSRect(x: 190, y: 190, width: 644, height: 644))
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
