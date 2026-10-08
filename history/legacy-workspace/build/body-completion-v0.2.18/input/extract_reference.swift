import AppKit
let source = CommandLine.arguments[1]
let destination = CommandLine.arguments[2]
guard let image = NSImage(contentsOfFile: source), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil), let crop = cg.cropping(to: CGRect(x:255,y:430,width:760,height:220)) else { fatalError("Missing source crop") }
let bitmap = NSBitmapImageRep(cgImage: crop)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath:destination))
print("Reference detail: \(crop.width)x\(crop.height)")
