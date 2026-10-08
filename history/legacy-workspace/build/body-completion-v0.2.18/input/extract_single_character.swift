import AppKit
let source = CommandLine.arguments[1]
let destination = CommandLine.arguments[2]
guard let image = NSImage(contentsOfFile: source), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil), let crop = cg.cropping(to: CGRect(x:425,y:0,width:560,height:527)) else { fatalError("Missing source crop") }
try NSBitmapImageRep(cgImage:crop).representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:destination))
