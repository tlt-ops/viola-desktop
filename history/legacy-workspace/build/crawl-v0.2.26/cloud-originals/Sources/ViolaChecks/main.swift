import Foundation
import CoreGraphics
import ViolaCore


var failures: [String] = []
var runningCase = ""
func fail(_ message: String) { failures.append("\(runningCase): \(message)") }
func checkEqual<T: Equatable>(_ actual: T, _ expected: T) { if actual != expected { fail("expected \(expected), got \(actual)") } }
func checkEqual(_ actual: Double, _ expected: Double, accuracy: Double) { if abs(actual - expected) > accuracy { fail("expected \(expected) ± \(accuracy), got \(actual)") } }
func checkTrue(_ value: Bool) { if !value { fail("expected true") } }
func checkFalse(_ value: Bool) { if value { fail("expected false") } }
func checkLess<T: Comparable>(_ a: T, _ b: T) { if !(a < b) { fail("\(a) must be less than \(b)") } }
func checkGreater<T: Comparable>(_ a: T, _ b: T) { if !(a > b) { fail("\(a) must be greater than \(b)") } }

final class ViolaCoreChecks {
    func testTypingLifecycleSingleBurstAndRelease() {
        let input = InputActivity(now: 0)
        var events: [SemanticEvent] = []; input.onSemanticEvent = { events.append($0) }
        input.receive(.keyDown(time: 1, isRepeat: false)); input.receive(.keyUp(time: 1.05))
        input.receive(.keyDown(time: 1.1, isRepeat: false)); input.receive(.keyUp(time: 1.2))
        input.update(now: 1.3); checkTrue(input.isTyping); checkEqual(input.keysHeld, 0)
        input.update(now: 2); checkFalse(input.isTyping); checkEqual(events, [.typingStart, .typingStop])
    }
    func testRepeatDoesNotInflateHeldKeys() {
        let input = InputActivity(now: 0)
        input.receive(.keyDown(time: 1, isRepeat: false))
        for n in 1...10 { input.receive(.keyDown(time: 1 + Double(n) * 0.02, isRepeat: true)) }
        checkEqual(input.keysHeld, 1)
        input.receive(.keyUp(time: 1.3)); checkEqual(input.keysHeld, 0)
    }
    func testFrequencyExpiresAndIdleMeasuresLastRealActivity() {
        let input = InputActivity(now: 0)
        for n in 0..<4 { input.receive(.keyDown(time: 1 + Double(n) * 0.1, isRepeat: false)) }
        checkEqual(input.frequency(now: 1.5), 2)
        input.update(now: 4); checkEqual(input.frequency(now: 4), 0)
        checkEqual(input.idleTime(now: 4), 2.7, accuracy: 0.001)
    }
    func testStationaryMouseDoesNotPreventSleep() {
        let input = InputActivity(now: 0)
        input.receive(.mouseMove(time: 59, x: 100, y: 100, dx: 0, dy: 0))
        checkEqual(input.idleTime(now: 61), 61)
    }
    func testSingleTapAndRecovery() {
        let engine = AnimationEngine(now: 0)
        engine.receive(.keyDown(time: 1, isRepeat: false))
        checkEqual(engine.tick(now: 1).state, .typing)
        checkGreater(engine.tick(now: 1.1).leftHandY, 5)
        checkEqual(engine.tick(now: 2).state, .idle)
        checkEqual(engine.tick(now: 2).leftHandY, 0, accuracy: 0.001)
    }
    func testBothClicksDepressMouseAndRecover() {
        for right in [false, true] {
            let engine = AnimationEngine(now: 0)
            engine.receive(right ? .rightClick(time: 1) : .leftClick(time: 1))
            let click = engine.tick(now: 1.12)
            checkEqual(click.state, .click); checkGreater(click.mousePress, 0.5)
            checkEqual(engine.tick(now: 2).mousePress, 0)
        }
    }
    func testMouseDirectionIsSmoothedAndReturnsToRest() {
        let engine = AnimationEngine(now: 0)
        engine.receive(.mouseMove(time: 1, x: 100, y: 100, dx: 20, dy: -10))
        let moving = engine.tick(now: 1.02)
        checkLess(moving.mouseX, 0); checkLess(moving.mouseY, 0)
        checkGreater(moving.mouseX, -13)
        var rest = moving
        for n in 0..<180 { rest = engine.tick(now: 2 + Double(n) / 60) }
        checkEqual(rest.mouseX, 0, accuracy: 0.001); checkEqual(rest.mouseY, 0, accuracy: 0.001)
    }
    func testSleepClosesEyesAndInputWakes() {
        let engine = AnimationEngine(now: 0); engine.activity.sleepDelay = 15
        let sleep = engine.tick(now: 16)
        checkEqual(sleep.state, .sleep); checkEqual(sleep.blink, 1)
        engine.receive(.mouseMove(time: 17, x: 100, y: 100, dx: 5, dy: 0))
        checkEqual(engine.tick(now: 17.4).state, .wake)
        checkEqual(engine.tick(now: 18).state, .idle)
    }
    func testBlinkIsTransientAndNotSustained() {
        let engine = AnimationEngine(now: 0)
        _ = engine.tick(now: 3.8)
        checkGreater(engine.tick(now: 3.89).blink, 0.9)
        checkEqual(engine.tick(now: 4.1).blink, 0)
    }
    func testReducedMotionRetainsVisibleInteraction() {
        let engine = AnimationEngine(now: 0)
        engine.receive(.keyDown(time: 1, isRepeat: false))
        let normal = engine.tick(now: 1)
        let reduced = engine.tick(now: 1, reducedMotion: true)
        checkLess(abs(reduced.leftHandY), abs(normal.leftHandY)); checkGreater(abs(reduced.leftHandY), 0)
    }
    func testConfigurationRoundTripAndCorruptRecovery() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(url: directory.appendingPathComponent("config.json"))
        var config = PetConfiguration(); config.width = 600; config.originX = -250; config.clickThrough = true; config.showDesks = false
        try store.save(config); checkEqual(store.load(), config)
        try Data("broken".utf8).write(to: store.url); checkEqual(store.load(), PetConfiguration())
    }
    func testConfigurationDeskVisibilityDefaultsForOlderFiles() throws {
        let older = try JSONDecoder().decode(PetConfiguration.self,from:Data("{\"version\":1,\"width\":600,\"clickThrough\":true}".utf8))
        checkTrue(older.showDesks); checkEqual(older.width,600); checkTrue(older.clickThrough)
        let hidden = try JSONDecoder().decode(PetConfiguration.self,from:Data("{\"showDesks\":false}".utf8))
        checkFalse(hidden.showDesks)
        let restored = try JSONDecoder().decode(PetConfiguration.self,from:JSONEncoder().encode(hidden))
        checkEqual(restored,hidden)
    }
    func testConfigurationBoundsAndPauseReset() {
        var config = PetConfiguration(); config.width = 9000; config.sleepAfter = -1; config.sanitize()
        checkEqual(config.width, 1200); checkEqual(config.sleepAfter, 15)
        let engine = AnimationEngine(now: 0); engine.receive(.leftClick(time: 1)); engine.reset(now: 2)
        let fresh = engine.tick(now: 2); checkEqual(fresh.state, .idle); checkEqual(fresh.mousePress, 0)
    }
    func testPhysicalKeyMapAndFingerRegions() {
        checkEqual(Set(KeyboardLayout.keys.map(\.code)).count, KeyboardLayout.keys.count)
        let expected: [(UInt16,String,TypingFinger)] = [(0,"A",.leftPinky),(1,"S",.leftRing),(2,"D",.leftMiddle),(3,"F",.leftIndex),(55,"⌘",.leftThumb),(49,"Space",.leftThumb),(38,"J",.leftIndex),(40,"K",.leftIndex),(37,"L",.leftIndex),(36,"Enter",.leftIndex)]
        for (code,label,finger) in expected {
            checkEqual(KeyboardLayout.byCode[code]?.label,label); checkEqual(KeyboardLayout.byCode[code]?.finger,finger)
        }
        checkEqual(Set(KeyboardLayout.keys.map(\.finger)), Set(TypingFinger.allCases.filter(\.isLeft)))
        checkTrue(KeyboardLayout.byCode[999] == nil)
    }
    func testIndependentChordKeycapsAndFingers() {
        let engine = AnimationEngine(now: 0)
        engine.receive(.keyDown(time: 1,isRepeat: false,keyCode: 0))
        engine.receive(.keyDown(time: 1.01,isRepeat: false,keyCode: 40))
        let frame = engine.tick(now: 1.02)
        checkEqual(frame.keyPressures[0],1); checkEqual(frame.keyPressures[40],1)
        checkEqual(frame.fingerPressures[.leftPinky],1); checkEqual(frame.fingerPressures[.leftIndex],1)
        checkTrue(frame.fingerPressures[.leftRing] == nil); checkTrue(frame.keyboardActive)
        checkEqual(frame.leftAim,40)
        engine.receive(.keyUp(time: 1.03,keyCode: 0))
        let released = engine.tick(now: 1.5)
        checkTrue(released.keyPressures[0] == nil); checkEqual(released.keyPressures[40],1)
        checkTrue(released.keyboardActive)
        engine.receive(.keyUp(time: 1.501,keyCode:123))
        checkTrue(engine.tick(now:1.505).keyPressures[123] == nil)
        engine.receive(.mouseMove(time: 1.51,x: 3,y: 3,dx: 3,dy: 3))
        let simultaneous = engine.tick(now: 1.52)
        checkTrue(simultaneous.keyboardActive); checkEqual(simultaneous.leftAim,40)
        checkTrue(simultaneous.mouseX < 0)
    }
    func testEveryRenderedKeyActivatesOnlyItsAssignedFinger() {
        for key in KeyboardLayout.keys {
            let engine = AnimationEngine(now: 0)
            engine.receive(.keyDown(time: 1,isRepeat: false,keyCode:key.code))
            let frame = engine.tick(now: 1.01)
            checkEqual(frame.keyPressures.count,1); checkEqual(frame.keyPressures[key.code],1)
            checkEqual(frame.fingerPressures.count,1); checkEqual(frame.fingerPressures[key.finger],1)
            checkEqual(frame.fingerKeys[key.finger],key.code)
            checkTrue(key.finger.isLeft); checkEqual(frame.leftAim,key.code)
            checkTrue(frame.fingerPressures.keys.allSatisfy(\.isLeft))
        }
    }
    func testPerKeyStatisticsRepeatAndPersistence() throws {
        var stats = KeyStatistics()
        stats.receive(.keyDown(time: 1,isRepeat: false,keyCode:0))
        stats.receive(.keyDown(time: 1.1,isRepeat: true,keyCode:0))
        stats.receive(.keyUp(time: 1.2,keyCode:0))
        stats.receive(.keyDown(time: 1.3,isRepeat: false,keyCode:36))
        checkEqual(stats.count(for:0).presses,1); checkEqual(stats.count(for:0).repeats,1)
        checkEqual(stats.count(for:36).presses,1); checkEqual(stats.count(for:1).presses,0)
        let saved = try JSONEncoder().encode(stats)
        let restored = try JSONDecoder().decode(KeyStatistics.self,from:saved)
        checkEqual(restored.count(for:0).presses,1); checkEqual(restored.count(for:0).repeats,1)
    }
    func testIdleLegsSettleOnInputAndRespectReducedMotion() {
        let engine = AnimationEngine(now:0,expressionSeed:42)
        var maxSwing = 0.0
        for n in 0..<600 {
            let frame = engine.tick(now:Double(n)/60)
            if n < 120 { checkEqual(frame.leftLegSwing,0) }
            checkLess(abs(frame.leftLegSwing),0.36001); checkLess(abs(frame.rightLegSwing),0.32001)
            maxSwing = max(maxSwing,abs(frame.leftLegSwing))
        }
        checkGreater(maxSwing,0.3)
        let normal = engine.tick(now:10), reduced = engine.tick(now:10,reducedMotion:true)
        checkEqual(reduced.leftLegSwing,normal.leftLegSwing*0.35,accuracy:0.000001)
        engine.receive(.keyDown(time:10.01,isRepeat:false,keyCode:0))
        var settled = AnimationFrame()
        for n in 1...120 { settled = engine.tick(now:10.01+Double(n)/60) }
        checkLess(abs(settled.leftLegSwing),0.0002)
        engine.reset(now:13); checkEqual(engine.tick(now:13).leftLegSwing,0)
    }
    func testFriendExpressionsAreTemporaryAndBothOccur() {
        let engine = AnimationEngine(now:0,expressionSeed:42)
        var seen = Set<String>(), longest = 0.0, streak = 0.0
        for n in 0..<3600 {
            let now = Double(n)/10
            // This case measures random expressions, independent of the longer
            // effort expression intentionally held during idle-triggered laughter.
            if n % 300 == 0 { engine.receive(.mouseMove(time:now,x:Double(n),y:0,dx:1,dy:0)) }
            let frame = engine.tick(now:now)
            checkEqual(frame.laugh,0)
            checkTrue(frame.friendExpressionOpacity >= 0 && frame.friendExpressionOpacity <= 1)
            if frame.friendExpression != .neutral {
                seen.insert(frame.friendExpression.rawValue); streak += 0.1; longest = max(longest,streak)
            } else { streak = 0 }
        }
        checkEqual(seen,Set(["effort","hearts"])); checkLess(longest,3.6)
        engine.reset(now:400); checkEqual(engine.tick(now:400).friendExpression,.neutral)
    }
    func testToeFieldKeepsCalfAndRootsFixedAndBoundsAllPixels() {
        var bare = ShoeFrame(); bare.phase = .grounded
        for side in ["back","front"] {
            let size = side == "back" ? CGSize(width:179,height:520) : CGSize(width:169,height:546)
            let motion = ToeMicroMotion(side:side,sourceSize:size,
                                        canvasSize:CGSize(width:size.width*0.64,height:size.height*0.64))
            for _ in 0..<90 {
                motion.advance(dt:0.1,shoe:bare,reducedMotion:false)
                for toe in motion.toes { checkEqual(motion.displacement(at:toe.root),.zero) }
                for x in stride(from:0,to:Int(size.width),by:3) {
                    checkEqual(motion.displacement(at:CGPoint(x:x,y:motion.meshSourceY)),.zero)
                    for y in stride(from:motion.meshSourceY,to:Int(size.height),by:3) {
                        let d = motion.displacement(at:CGPoint(x:x,y:y))
                        checkTrue(hypot(d.x,d.y) <= 0.95+0.000001)
                    }
                }
            }
        }
    }
    func testToeMotionIsIndependentAcrossDigitsAndFeet() {
        var bare = ShoeFrame(); bare.phase = .grounded
        let front = ToeMicroMotion(side:"front",sourceSize:CGSize(width:169,height:546),canvasSize:CGSize(width:108.16,height:349.44))
        let back = ToeMicroMotion(side:"back",sourceSize:CGSize(width:179,height:520),canvasSize:CGSize(width:114.56,height:332.8))
        let initial = front.tipDisplacements
        for _ in 0..<45 {
            front.advance(dt:1/30,shoe:bare,reducedMotion:false)
            back.advance(dt:1/30,shoe:bare,reducedMotion:false)
        }
        for index in 0..<5 {
            checkGreater(hypot(front.tipDisplacements[index].x-initial[index].x,
                               front.tipDisplacements[index].y-initial[index].y),0.02)
            checkTrue(front.tipDisplacements[index] != back.tipDisplacements[index])
            for other in (index+1)..<5 { checkTrue(front.tipDisplacements[index] != front.tipDisplacements[other]) }
        }
    }
    func testToeMotionRespectsFittingAndReducedMotion() {
        let motion = ToeMicroMotion(side:"front",sourceSize:CGSize(width:169,height:546),canvasSize:CGSize(width:108.16,height:349.44))
        var shoe = ShoeFrame(); shoe.phase = .grounded
        motion.advance(dt:0,shoe:shoe,reducedMotion:false); let bare = motion.tipDisplacements
        for phase in [ShoePhase.halfWorn,.slipping,.recovering] {
            shoe.phase = phase; shoe.recovery = .toeHook
            motion.advance(dt:0,shoe:shoe,reducedMotion:false)
            for index in 0..<5 {
                checkEqual(Double(motion.tipDisplacements[index].x),Double(bare[index].x)*0.15,accuracy:0.000001)
                checkEqual(Double(motion.tipDisplacements[index].y),Double(bare[index].y)*0.15,accuracy:0.000001)
            }
        }
        motion.advance(dt:0.03,shoe:shoe,reducedMotion:true)
        checkFalse(motion.enabled); checkEqual(motion.amplitudeLimit,0)
        for vector in motion.tipDisplacements { checkEqual(vector,.zero) }
    }
    func testToeClockBoundsSuspendAndRejectsInvalidDelta() {
        let motion = ToeMicroMotion(side:"back",sourceSize:CGSize(width:179,height:520),canvasSize:CGSize(width:114.56,height:332.8))
        motion.advance(dt:100,shoe:ShoeFrame(),reducedMotion:false)
        checkEqual(motion.time,0.1,accuracy:0.000001)
        motion.advance(dt:-1,shoe:ShoeFrame(),reducedMotion:false)
        motion.advance(dt:.infinity,shoe:ShoeFrame(),reducedMotion:false)
        motion.advance(dt:.nan,shoe:ShoeFrame(),reducedMotion:false)
        checkEqual(motion.time,0.1,accuracy:0.000001)
    }
}

let suite = ViolaCoreChecks()
let cases: [(String, () throws -> Void)] = [
    ("testTypingLifecycleSingleBurstAndRelease", suite.testTypingLifecycleSingleBurstAndRelease),
    ("testRepeatDoesNotInflateHeldKeys", suite.testRepeatDoesNotInflateHeldKeys),
    ("testFrequencyExpiresAndIdleMeasuresLastRealActivity", suite.testFrequencyExpiresAndIdleMeasuresLastRealActivity),
    ("testStationaryMouseDoesNotPreventSleep", suite.testStationaryMouseDoesNotPreventSleep),
    ("testSingleTapAndRecovery", suite.testSingleTapAndRecovery),
    ("testBothClicksDepressMouseAndRecover", suite.testBothClicksDepressMouseAndRecover),
    ("testMouseDirectionIsSmoothedAndReturnsToRest", suite.testMouseDirectionIsSmoothedAndReturnsToRest),
    ("testSleepClosesEyesAndInputWakes", suite.testSleepClosesEyesAndInputWakes),
    ("testBlinkIsTransientAndNotSustained", suite.testBlinkIsTransientAndNotSustained),
    ("testReducedMotionRetainsVisibleInteraction", suite.testReducedMotionRetainsVisibleInteraction),
    ("testConfigurationRoundTripAndCorruptRecovery", suite.testConfigurationRoundTripAndCorruptRecovery),
    ("testConfigurationDeskVisibilityDefaultsForOlderFiles", suite.testConfigurationDeskVisibilityDefaultsForOlderFiles),
    ("testConfigurationBoundsAndPauseReset", suite.testConfigurationBoundsAndPauseReset),
    ("testPhysicalKeyMapAndFingerRegions", suite.testPhysicalKeyMapAndFingerRegions),
    ("testIndependentChordKeycapsAndFingers", suite.testIndependentChordKeycapsAndFingers),
    ("testEveryRenderedKeyActivatesOnlyItsAssignedFinger", suite.testEveryRenderedKeyActivatesOnlyItsAssignedFinger),
    ("testPerKeyStatisticsRepeatAndPersistence", suite.testPerKeyStatisticsRepeatAndPersistence),
    ("testIdleLegsSettleOnInputAndRespectReducedMotion", suite.testIdleLegsSettleOnInputAndRespectReducedMotion),
    ("testFriendExpressionsAreTemporaryAndBothOccur", suite.testFriendExpressionsAreTemporaryAndBothOccur),
    ("testToeFieldKeepsCalfAndRootsFixedAndBoundsAllPixels", suite.testToeFieldKeepsCalfAndRootsFixedAndBoundsAllPixels),
    ("testToeMotionIsIndependentAcrossDigitsAndFeet", suite.testToeMotionIsIndependentAcrossDigitsAndFeet),
    ("testToeMotionRespectsFittingAndReducedMotion", suite.testToeMotionRespectsFittingAndReducedMotion),
    ("testToeClockBoundsSuspendAndRejectsInvalidDelta", suite.testToeClockBoundsSuspendAndRejectsInvalidDelta)
]
for (name, body) in cases {
    runningCase = name
    let previousFailures = failures.count
    do { try body() } catch { fail("unexpected error: \(error)") }
    print("\(previousFailures == failures.count ? "PASS" : "FAIL") \(name)")
}
if !failures.isEmpty { for item in failures { fputs(item + "\n", stderr) }; exit(1) }
print("PASS: \(cases.count) core behavior checks")
