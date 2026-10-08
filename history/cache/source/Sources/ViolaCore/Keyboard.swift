import Foundation

public enum TypingFinger: String, Codable, CaseIterable {
    case leftPinky, leftRing, leftMiddle, leftIndex, leftThumb
    case rightThumb, rightIndex, rightMiddle, rightRing, rightPinky
    public var isLeft: Bool { rawValue.hasPrefix("left") }
    public var name: String {
        switch self {
        case .leftPinky: return "左小指"; case .leftRing: return "左无名指"
        case .leftMiddle: return "左中指"; case .leftIndex: return "左食指"
        case .leftThumb: return "左拇指"; case .rightThumb: return "右拇指"
        case .rightIndex: return "右食指"; case .rightMiddle: return "右中指"
        case .rightRing: return "右无名指"; case .rightPinky: return "右小指"
        }
    }
}
public struct PhysicalKey {
    public let code: UInt16
    public let label: String
    public let row: Int
    public let column: Double
    public let width: Double
    public let finger: TypingFinger
}
/// Physical ANSI positions, from the installed macOS SDK's HIToolbox Events.h.
/// Viola types with her left hand while her right hand keeps hold of the mouse.
public enum KeyboardLayout {
    public static let keys: [PhysicalKey] = {
        var result: [PhysicalKey] = []
        func row(_ n: Int, _ entries: [(UInt16, String, Double, TypingFinger)], start: Double = 0) {
            var column = start
            for (code, label, width, finger) in entries {
                // Keep the familiar ASDF zones. The index reaches across the right
                // half of the board; the thumb handles Space and bottom modifiers.
                let keyboardFinger = finger.isLeft ? finger : (finger == .rightThumb ? .leftThumb : .leftIndex)
                result.append(PhysicalKey(code: code, label: label, row: n, column: column, width: width, finger: keyboardFinger)); column += width
            }
        }
        row(0, [(53,"Esc",1,.leftPinky),(122,"F1",1,.leftPinky),(120,"F2",1,.leftRing),(99,"F3",1,.leftMiddle),(118,"F4",1,.leftIndex),(96,"F5",1,.leftIndex),(97,"F6",1,.rightIndex),(98,"F7",1,.rightIndex),(100,"F8",1,.rightMiddle),(101,"F9",1,.rightRing),(109,"F10",1,.rightPinky),(103,"F11",1,.rightPinky),(111,"F12",1,.rightPinky),(117,"Del",2,.rightPinky)])
        row(1, [(50,"`",1,.leftPinky),(18,"1",1,.leftPinky),(19,"2",1,.leftRing),(20,"3",1,.leftMiddle),(21,"4",1,.leftIndex),(23,"5",1,.leftIndex),(22,"6",1,.rightIndex),(26,"7",1,.rightIndex),(28,"8",1,.rightMiddle),(25,"9",1,.rightRing),(29,"0",1,.rightPinky),(27,"−",1,.rightPinky),(24,"=",1,.rightPinky),(51,"⌫",2,.rightPinky)])
        row(2, [(48,"Tab",1.5,.leftPinky),(12,"Q",1,.leftPinky),(13,"W",1,.leftRing),(14,"E",1,.leftMiddle),(15,"R",1,.leftIndex),(17,"T",1,.leftIndex),(16,"Y",1,.rightIndex),(32,"U",1,.rightIndex),(34,"I",1,.rightMiddle),(31,"O",1,.rightRing),(35,"P",1,.rightPinky),(33,"[",1,.rightPinky),(30,"]",1,.rightPinky),(42,"\\",1.5,.rightPinky)])
        row(3, [(57,"Caps",1.75,.leftPinky),(0,"A",1,.leftPinky),(1,"S",1,.leftRing),(2,"D",1,.leftMiddle),(3,"F",1,.leftIndex),(5,"G",1,.leftIndex),(4,"H",1,.rightIndex),(38,"J",1,.rightIndex),(40,"K",1,.rightMiddle),(37,"L",1,.rightRing),(41,";",1,.rightPinky),(39,"'",1,.rightPinky),(36,"Enter",2.25,.rightPinky)])
        row(4, [(56,"Shift",2.25,.leftPinky),(6,"Z",1,.leftPinky),(7,"X",1,.leftRing),(8,"C",1,.leftMiddle),(9,"V",1,.leftIndex),(11,"B",1,.leftIndex),(45,"N",1,.rightIndex),(46,"M",1,.rightIndex),(43,",",1,.rightMiddle),(47,".",1,.rightRing),(44,"/",1,.rightPinky),(60,"Shift",1.75,.rightPinky),(126,"↑",1,.rightMiddle)])
        row(5, [(63,"fn",1,.leftPinky),(59,"Ctrl",1,.leftPinky),(58,"⌥",1,.leftThumb),(55,"⌘",1.25,.leftThumb),(49,"Space",6.25,.rightThumb),(54,"⌘",1.25,.rightThumb),(61,"⌥",1.25,.rightThumb),(123,"←",1,.rightIndex),(125,"↓",1,.rightMiddle),(124,"→",1,.rightRing)])
        row(0, [(115,"Home",1,.rightPinky)], start: 15.25)
        row(1, [(116,"PgUp",1,.rightPinky)], start: 15.25)
        row(2, [(121,"PgDn",1,.rightPinky)], start: 15.25)
        row(3, [(119,"End",1,.rightPinky)], start: 15.25)
        return result
    }()
    public static let byCode = Dictionary(uniqueKeysWithValues: keys.map { ($0.code, $0) })
    public static func label(for code: UInt16) -> String {
        if let key = byCode[code] { return key.label }
        let extras: [UInt16: String] = [62:"右 Ctrl",65:"Num .",67:"Num ×",69:"Num +",71:"Num Clear",75:"Num ÷",76:"Num Enter",78:"Num −",81:"Num =",82:"Num 0",83:"Num 1",84:"Num 2",85:"Num 3",86:"Num 4",87:"Num 5",88:"Num 6",89:"Num 7",91:"Num 8",92:"Num 9",72:"音量 +",73:"音量 −",74:"静音",10:"ISO",93:"JIS ¥",94:"JIS _",95:"JIS Num ,",102:"JIS 英数",104:"JIS 假名"]
        let functions: [UInt16:String] = [64:"F17",79:"F18",80:"F19",90:"F20",105:"F13",106:"F16",107:"F14",113:"F15",114:"Help",110:"Menu"]
        return extras[code] ?? functions[code] ?? "Key \(code)"
    }
}
public struct KeyCount: Codable { public var presses = 0; public var repeats = 0 }
public struct KeyStatistics: Codable {
    public var counts: [String: KeyCount] = [:]
    public init() {}
    public mutating func receive(_ event: InputEvent) {
        guard case .keyDown(_, let repeated, let code) = event, let code else { return }
        var value = counts[String(code)] ?? KeyCount()
        if repeated { value.repeats += 1 } else { value.presses += 1 }
        counts[String(code)] = value
    }
    public func count(for code: UInt16) -> KeyCount { counts[String(code)] ?? KeyCount() }
}
