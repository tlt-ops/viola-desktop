import CoreGraphics
import Foundation

/// Saved original hand-to-abdomen pose. Keep these values independent of the
/// ordinary keyboard/mouse solver so input edits do not redesign the laugh.
enum OriginalLaughPose {
    static let leftWrist = CGPoint(x:317,y:648)
    static let rightWrist = CGPoint(x:405,y:643)
    static func weight(_ value: Double) -> Double { smooth(value) }
    static func leftAngle(_ weight: Double) -> Double { pow(weight,5)*0.8 }
    static func rightAngle(_ weight: Double) -> Double { -weight*0.30 }
    static func keyboardBlend(_ weight: Double) -> Double { smooth(weight/0.35) }
    static func keyboardSleeve(_ weight: Double) -> Double { weight >= 0.25 ? 1 : 0 }
    static func wrist(normal: CGPoint, belly: CGPoint, shoulder: CGPoint, weight: Double) -> CGPoint {
        CGPoint(x:normal.x+(belly.x+shoulder.x-normal.x)*weight,
                y:normal.y+(belly.y+shoulder.y-normal.y)*weight)
    }
    private static func smooth(_ value: Double) -> Double {
        let v = max(0,min(1,value)); return v*v*(3-2*v)
    }
}
