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
    func testFixedLaughIgnoresConcurrentKeyboardAndMouse() {
        let quiet = AnimationEngine(now:0,expressionSeed:42)
        let busy = AnimationEngine(now:0,expressionSeed:42)
        quiet.allowsShoeDrops = false; busy.allowsShoeDrops = false
        checkTrue(quiet.startLaugh(now:0)); checkTrue(busy.startLaugh(now:0))
        for n in 0...(Int(FixedLaughMotion.duration*60)+24) {
            let now = Double(n)/60
            if n.isMultiple(of:6) {
                busy.receive(.keyDown(time:now,isRepeat:false,keyCode:UInt16(n % 82)))
                busy.receive(.mouseMove(time:now,x:0,y:0,dx:n.isMultiple(of:12) ? 25 : -25,dy:15))
            }
            if n % 6 == 2 { busy.receive(.keyUp(time:now,keyCode:UInt16((n-2) % 82))) }
            let a = quiet.tick(now:now), b = busy.tick(now:now)
            checkEqual(a.laugh,b.laugh,accuracy:0.0000001)
            checkEqual(a.laughAge,b.laughAge,accuracy:0.0000001)
            checkEqual(a.laughBounce,b.laughBounce,accuracy:0.0000001)
            checkEqual(a.supportSway,b.supportSway,accuracy:0.0000001)
            checkEqual(a.supportDip,b.supportDip,accuracy:0.0000001)
            if a.laugh == 1 {
                checkEqual(a.leftLegSwing,b.leftLegSwing,accuracy:0.0000001)
                checkEqual(a.rightLegSwing,b.rightLegSwing,accuracy:0.0000001)
                checkEqual(a.friendExpression,.effort); checkEqual(b.friendExpression,.effort)
            }
        }
        let finished = FixedLaughMotion.duration+0.4
        checkEqual(quiet.tick(now:finished).laugh,0); checkEqual(busy.tick(now:finished).laugh,0)
    }
    func testNaturalLaughTearsPrecedeWipeAndClearBeforeHandLowers() {
        checkEqual(FixedLaughMotion.tearWeight(age:3),0)
        checkGreater(FixedLaughMotion.tearWeight(age:4),0.9)
        checkEqual(FixedLaughMotion.wipeWeight(age:4),0)
        // The wipe must still be part of the active clip after the old 5.6s end.
        checkEqual(FixedLaughMotion.weight(age:6),1)
        checkEqual(FixedLaughMotion.wipeWeight(age:6),1)
        checkGreater(FixedLaughMotion.tearWeight(age:5.6),0.9)
        checkEqual(FixedLaughMotion.tearWeight(age:6.5),0)
        checkEqual(FixedLaughMotion.wipeWeight(age:6.5),1)
        checkEqual(FixedLaughMotion.wipeWeight(age:7.2),0)
        checkEqual(FixedLaughMotion.weight(age:7.2),1)
        var positiveStroke = false, negativeStroke = false
        for n in 450...800 {
            let age = Double(n)/100
            checkEqual(FixedLaughMotion.bounce(age:age),0,accuracy:0.0000001)
            let stroke = FixedLaughMotion.wipeStroke(age:age)
            checkLess(abs(stroke),2)
            positiveStroke = positiveStroke || stroke > 0.5
            negativeStroke = negativeStroke || stroke < -0.5
            if stroke != 0 { checkEqual(FixedLaughMotion.wipeWeight(age:age),1) }
        }
        checkTrue(positiveStroke); checkTrue(negativeStroke)
        for age in [-1.0,0,FixedLaughMotion.duration,FixedLaughMotion.duration+1] {
            checkEqual(FixedLaughMotion.tearWeight(age:age),0)
            checkEqual(FixedLaughMotion.wipeWeight(age:age),0)
            checkEqual(FixedLaughMotion.wipeStroke(age:age),0)
        }
        checkEqual(FixedLaughMotion.weight(age:FixedLaughMotion.duration),0)
    }
    func testLayeredLaughMotionRangesContinuityAndNeutralRecovery() {
        checkEqual(FixedLaughMotion.revision,"layered-belly-laugh-v3")
        checkEqual(FixedLaughMotion.duration,8)
        let curves: [(Double) -> Double] = [
            { FixedLaughMotion.torsoRotation(age:$0) },
            { FixedLaughMotion.headNod(age:$0) },
            { FixedLaughMotion.chestCompression(age:$0) },
            { FixedLaughMotion.shoulderLift(age:$0) },
            { FixedLaughMotion.hairSway(age:$0) }
        ]
        let neutral = [0.0,0,1,0,0]
        let maximumStep = [0.004,0.008,0.006,0.4,0.005]
        var previous = curves.map { $0(0) }
        var maximumHead = 0.0, minimumChest = 1.0, maximumChest = 1.0
        for n in 0...960 {
            let age = Double(n)/120
            let values = curves.map { $0(age) }
            for index in values.indices {
                checkTrue(values[index].isFinite)
                checkLess(abs(values[index]-previous[index]),maximumStep[index])
            }
            checkLess(abs(values[0]),0.05); checkLess(abs(values[1]),0.055)
            checkGreater(values[2],0.969); checkLess(values[2],1.021)
            checkLess(abs(values[3]),3.01); checkLess(abs(values[4]),0.04)
            maximumHead = max(maximumHead,values[1])
            minimumChest = min(minimumChest,values[2]); maximumChest = max(maximumChest,values[2])
            previous = values
        }
        checkGreater(maximumHead,0.03)
        checkLess(minimumChest,0.98); checkGreater(maximumChest,1.01)
        for age in [-1.0,0,8,9,Double.infinity,Double.nan] {
            for index in curves.indices { checkEqual(curves[index](age),neutral[index],accuracy:0.0000001) }
        }
        for index in curves.indices {
            checkEqual(curves[index](8-0.000001),neutral[index],accuracy:0.000001)
        }
        // Hair receives the earlier head motion, not an identical synchronous
        // rotation; sample before the terminal settling envelope takes effect.
        checkEqual(FixedLaughMotion.hairSway(age:1.10),FixedLaughMotion.headNod(age:1.02)*0.65,accuracy:0.0000001)
        checkGreater(abs(FixedLaughMotion.hairSway(age:1.02)-FixedLaughMotion.headNod(age:1.02)*0.65),0.001)
    }
    func testFrameCadenceActiveDoesNotSkipJitteredTicks() {
        var cadence = FrameCadence()
        var drawCount = 0, oldGateCount = 0
        var oldLastDraw = 359_999.0
        for n in 0..<600 {
            let now = 360_000 + Double(n) / 60 + (n.isMultiple(of: 2) ? -0.001 : 0.001)
            if cadence.shouldDraw(now: now, state: .laugh, framesPerSecond: 60, isTimerTick: true) { drawCount += 1 }
            if now - oldLastDraw >= 1.0 / 60 { oldGateCount += 1; oldLastDraw = now }
            if n.isMultiple(of: 29) {
                checkTrue(cadence.shouldDraw(now: now + 0.0002, state: .laugh, framesPerSecond: 60, isTimerTick: false))
            }
        }
        checkEqual(drawCount, 600)
        // The previous elapsed gate loses real timer frames even with only 1 ms jitter.
        checkLess(oldGateCount, 450)
    }
    func testFrameCadenceSlowModesKeepPhaseThroughJitter() {
        let jitter = [0.001, -0.002, 0.0015, -0.001, 0.002, -0.0015]
        for fps in [30.0, 15.0] {
            var cadence = FrameCadence(), draws = 0
            let stride = Int(60 / fps)
            for n in 0...12_000 {
                let now = 360_000 + Double(n) / 60 + jitter[n % jitter.count]
                let draw = cadence.shouldDraw(now: now, state: .idle, framesPerSecond: fps, isTimerTick: true)
                checkEqual(draw, n.isMultiple(of: stride))
                if draw { draws += 1 }
            }
            checkEqual(draws, 12_000 / stride + 1)
        }
    }
    func testFrameCadenceEventsDoNotShiftSlowPhase() {
        var cadence = FrameCadence()
        checkTrue(cadence.shouldDraw(now: 0, state: .idle, framesPerSecond: 30, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 0.01, state: .idle, framesPerSecond: 30, isTimerTick: false))
        checkFalse(cadence.shouldDraw(now: 1.0 / 60, state: .idle, framesPerSecond: 30, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 2.0 / 60, state: .idle, framesPerSecond: 30, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 0.049, state: .idle, framesPerSecond: 30, isTimerTick: false))
        checkFalse(cadence.shouldDraw(now: 3.0 / 60, state: .idle, framesPerSecond: 30, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 4.0 / 60, state: .idle, framesPerSecond: 30, isTimerTick: true))
    }
    func testFrameCadenceSkipsMissedSlotsAndResetsOnTransitions() {
        var cadence = FrameCadence()
        checkTrue(cadence.shouldDraw(now: 0, state: .sleep, framesPerSecond: 15, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 4.011, state: .sleep, framesPerSecond: 15, isTimerTick: true))
        checkFalse(cadence.shouldDraw(now: 4.02, state: .sleep, framesPerSecond: 15, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 4.066666667, state: .sleep, framesPerSecond: 15, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 4.067, state: .idle, framesPerSecond: 30, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 4.068, state: .idle, framesPerSecond: 60, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 4.069, state: .crawl, framesPerSecond: 60, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 4.070, state: .idle, framesPerSecond: 30, isTimerTick: true))
        checkFalse(cadence.shouldDraw(now: 4.08, state: .idle, framesPerSecond: 30, isTimerTick: true))
        cadence.reset()
        checkTrue(cadence.shouldDraw(now: 900, state: .idle, framesPerSecond: 30, isTimerTick: true))
        checkFalse(cadence.shouldDraw(now: 900.01, state: .idle, framesPerSecond: 30, isTimerTick: true))
        checkTrue(cadence.shouldDraw(now: 900 + 1.0 / 30, state: .idle, framesPerSecond: 30, isTimerTick: true))
    }
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
    func testFriendBlinkHasIndependentContinuousTiming() {
        let engine = AnimationEngine(now: 0, expressionSeed: 42)
        _ = engine.tick(now: 3.8)
        let riderClosed = engine.tick(now: 3.89)
        checkGreater(riderClosed.blink, 0.9)
        checkEqual(riderClosed.friendBlink, 0)
        _ = engine.tick(now: 5.1)
        let partial = engine.tick(now: 5.15)
        checkGreater(partial.friendBlink, 0); checkLess(partial.friendBlink, 1)
        let friendClosed = engine.tick(now: 5.21)
        checkGreater(friendClosed.friendBlink, 0.9)
        checkEqual(friendClosed.blink, 0)
        checkEqual(engine.tick(now: 5.35).friendBlink, 0)
        engine.reset(now: 10)
        checkEqual(engine.tick(now: 10).friendBlink, 0)
        engine.activity.sleepDelay = 15
        let sleeping = engine.tick(now: 26)
        checkEqual(sleeping.friendBlink, 1)
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
        checkTrue(older.idleCrawlEnabled)
        let crawlDisabled = try JSONDecoder().decode(PetConfiguration.self,from:Data("{\"idleCrawlEnabled\":false}".utf8))
        checkFalse(crawlDisabled.idleCrawlEnabled)
        checkFalse(try JSONDecoder().decode(PetConfiguration.self,from:JSONEncoder().encode(crawlDisabled)).idleCrawlEnabled)
        let restored = try JSONDecoder().decode(PetConfiguration.self,from:JSONEncoder().encode(hidden))
        checkEqual(restored,hidden)
    }
    func testAutomaticSleepConfigurationDefaultsAndRoundTrip() throws {
        checkFalse(PetConfiguration().automaticSleepEnabled)
        let older = try JSONDecoder().decode(PetConfiguration.self,from:Data("{\"sleepAfter\":120}".utf8))
        checkFalse(older.automaticSleepEnabled); checkEqual(older.sleepAfter,120)
        var enabled = older; enabled.automaticSleepEnabled = true
        let restored = try JSONDecoder().decode(PetConfiguration.self,from:JSONEncoder().encode(enabled))
        checkTrue(restored.automaticSleepEnabled); checkEqual(restored.sleepAfter,120)
        enabled.automaticSleepEnabled = false
        checkFalse(try JSONDecoder().decode(PetConfiguration.self,from:JSONEncoder().encode(enabled)).automaticSleepEnabled)
    }
    func testDisabledAutomaticSleepRetainsLongIdleBlinkAndBreath() {
        let engine = AnimationEngine(now:0,expressionSeed:42)
        engine.activity.sleepDelay = .infinity; engine.allowsShoeDrops = false
        // Let the automatic idle laugh finish first, so it cannot hide a sleep
        // regression or affect the normal idle expression assertions.
        _ = engine.tick(now:600)
        let settled = 600+AnimationEngine.laughDuration
        let open = engine.tick(now:settled)
        checkEqual(open.state,.idle)
        let riderClosed = engine.tick(now:settled+0.09)
        checkGreater(riderClosed.blink,0.9)
        let friendClosed = engine.tick(now:settled+0.13)
        checkGreater(friendClosed.friendBlink,0.9)
        let reopened = engine.tick(now:settled+0.30)
        checkEqual(reopened.state,.idle)
        checkEqual(reopened.blink,0); checkEqual(reopened.friendBlink,0)
        checkGreater(abs(reopened.breath-open.breath),0.01)
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
    func testCrawlTravelIsIndependentOfFrameRateAndDirection() {
        checkEqual(CrawlMotion.duration,27.36,accuracy:0.000001)
        checkEqual(CrawlMotion.cycleDuration,0.72,accuracy:0.000001)
        checkEqual(CrawlMotion.settlementDuration,0.208,accuracy:0.000001)
        checkEqual(CrawlMotion.maximumTravel,1496,accuracy:0.000001)
        for dt in [1.0/120, 1.0/30, 0.137, 10.0] {
            for direction in [-1.0, 1.0] {
                let gait = CrawlMotion(); checkTrue(gait.start(now:0,direction:direction))
                var sum = 0.0, maximum = 0.0
                var now = 0.0
                while now < CrawlMotion.duration + dt {
                    let frame = gait.tick(now:now)
                    sum += frame.deltaX; maximum = max(maximum,frame.distance)
                    checkTrue(frame.distance >= 0 && frame.distance <= CrawlMotion.maximumTravel)
                    now += dt
                }
                let end = gait.tick(now:CrawlMotion.duration+dt)
                sum += end.deltaX
                checkEqual(sum,direction*CrawlMotion.maximumTravel,accuracy:0.000001)
                checkEqual(maximum,CrawlMotion.maximumTravel,accuracy:0.000001)
                checkFalse(gait.isActive); checkEqual(end.weight,0); checkEqual(end.deltaX,0,accuracy:0.000001)
            }
        }
        // Alternating short frames and long skips must integrate the same full path.
        let irregular = CrawlMotion(); _ = irregular.start(now:0,direction:1)
        var irregularTime = 0.0, irregularSum = 0.0, sample = 0
        let intervals = [1.0/120, 0.071, 0.003, 0.82, 0.019]
        while irregularTime < CrawlMotion.duration {
            irregularTime = min(CrawlMotion.duration, irregularTime + intervals[sample % intervals.count])
            irregularSum += irregular.tick(now:irregularTime).deltaX
            sample += 1
        }
        checkEqual(irregularSum,CrawlMotion.maximumTravel,accuracy:0.000001)
        checkFalse(irregular.isActive)
        checkEqual(irregular.tick(now:CrawlMotion.duration + 1).deltaX,0)
    }
    func testCrawlContactsAlternateAndStanceCompensatesTravel() {
        let gait = CrawlMotion(); checkTrue(gait.start(now:0,direction:1))
        // At phase 0.8 the back palm/front knee swing; half a cycle later
        // the front palm/back knee swing. The other diagonal stays grounded.
        let backSwing = gait.tick(now:CrawlMotion.cycleDuration * 0.8)
        checkGreater(backSwing.backHandY,19); checkEqual(backSwing.frontHandY,0)
        checkGreater(backSwing.frontKneeY,9); checkEqual(backSwing.backKneeY,0)
        let frontSwing = gait.tick(now:CrawlMotion.cycleDuration * 1.3)
        checkGreater(frontSwing.frontHandY,19); checkEqual(frontSwing.backHandY,0)
        checkGreater(frontSwing.backKneeY,9); checkEqual(frontSwing.frontKneeY,0)
        let a = gait.tick(now:CrawlMotion.cycleDuration * 2.1), b = gait.tick(now:CrawlMotion.cycleDuration * 2.3)
        checkEqual(a.backHandY,0); checkEqual(b.backHandY,0)
        checkEqual(b.backHandX-a.backHandX,-b.deltaX,accuracy:0.000001)
        checkEqual(b.phase-a.phase,0.2,accuracy:0.000001)
        checkEqual(b.deltaX,55 * CrawlMotion.cycleDuration * 0.2,accuracy:0.000001)
        // The larger lift keeps the previous palm stride despite slower travel.
        checkEqual(a.backHandX,110 * 0.36 * 0.65 * (0.5 - 0.1 / 0.65),accuracy:0.000001)
        let bodyPeak = gait.tick(now:CrawlMotion.cycleDuration * 3.25)
        checkEqual(bodyPeak.bodyX,2.25,accuracy:0.000001)
        checkEqual(bodyPeak.bodyRoll,0.027,accuracy:0.000001)
        let liftPeak = gait.tick(now:CrawlMotion.cycleDuration * 3.825)
        checkEqual(liftPeak.backHandY,21,accuracy:0.000001)
        checkEqual(liftPeak.frontKneeY,10.5,accuracy:0.000001)
    }
    func testCrawlEntryExitAndCancellationAreSmoothAndBounded() {
        let gait = CrawlMotion(); _ = gait.start(now:0,direction:1)
        var previous = gait.tick(now:0), previousWeight = 0.0
        for n in 1...Int(CrawlMotion.duration * 2000) {
            let frame = gait.tick(now:Double(n)/2000)
            checkTrue(frame.weight >= 0 && frame.weight <= 1)
            checkLess(abs(frame.weight-previousWeight),0.05)
            checkLess(abs(frame.riderBounce),1.50001); checkLess(abs(frame.bodyRoll),0.02701)
            checkLess(abs(frame.bodyX),2.25001); checkLess(abs(frame.bodyY),3.15001)
            checkLess(abs(frame.frontKneeX),10.50001); checkLess(abs(frame.backKneeX),10.50001)
            checkLess(abs(frame.backHandX-previous.backHandX),1)
            checkLess(abs(frame.frontHandX-previous.frontHandX),1)
            previous = frame; previousWeight = frame.weight
        }
        checkEqual(previous.weight,0); checkFalse(previous.active)
        _ = gait.start(now:10,direction:-1)
        let stoppedAt = 10 + CrawlMotion.cycleDuration * 0.8
        let moving = gait.tick(now:stoppedAt)
        gait.stop(now:stoppedAt)
        let unchanged = gait.tick(now:stoppedAt)
        checkEqual(unchanged.backHandY,moving.backHandY,accuracy:0.000001)
        let halfway = gait.tick(now:stoppedAt + CrawlMotion.settlementDuration / 2)
        checkEqual(halfway.weight,moving.weight*0.5,accuracy:0.000001)
        checkEqual(halfway.distance,moving.distance,accuracy:0.000001); checkEqual(halfway.deltaX,0)
        let settled = gait.tick(now:stoppedAt + CrawlMotion.settlementDuration + 0.001)
        checkFalse(gait.isActive); checkEqual(settled.weight,0); checkEqual(settled.backHandY,0)
        _ = gait.start(now:12,direction:1); _ = gait.tick(now:12.02)
        gait.stop(now:12.023); gait.stop(now:12.025,immediate:true)
        checkFalse(gait.isActive)
        let dragged = gait.tick(now:12.03)
        checkEqual(dragged.weight,0); checkEqual(dragged.deltaX,0)
    }
    func testCrawlInputCancellationAndQueuedLaugh() {
        let engine = AnimationEngine(now:0,expressionSeed:42)
        checkTrue(engine.startCrawl(now:0,direction:1)); checkFalse(engine.startCrawl(now:0,direction:-1))
        checkEqual(engine.tick(now:0.1).state,.crawl)
        engine.receive(.mouseMove(time:0.11,x:0,y:0,dx:0,dy:0))
        checkTrue(engine.tick(now:0.14).crawl.active)
        engine.receive(.keyDown(time:0.14,isRepeat:false,keyCode:0))
        checkTrue(engine.tick(now:0.15).crawl.active)
        checkFalse(engine.tick(now:0.14 + CrawlMotion.settlementDuration + 0.001).crawl.active)
        engine.receive(.keyUp(time:0.14 + CrawlMotion.settlementDuration + 0.002,keyCode:0)); _ = engine.tick(now:0.8)
        checkTrue(engine.startCrawl(now:0.8,direction:-1)); _ = engine.tick(now:0.88)
        checkFalse(engine.startLaugh(now:0.88)); checkTrue(engine.isCrawling)
        let settling = engine.tick(now:0.89); checkEqual(settling.laugh,0)
        let laughing = engine.tick(now:0.88 + CrawlMotion.settlementDuration + 0.001)
        checkFalse(laughing.crawl.active); checkEqual(laughing.state,.laugh)
        checkFalse(engine.startCrawl(now:0.88 + CrawlMotion.settlementDuration + 0.001,direction:1))
        engine.reset(now:1.2); checkFalse(engine.isCrawling)
        checkEqual(engine.tick(now:1.2).crawl.distance,0)
        checkTrue(engine.startCrawl(now:1.2,direction:1)); _ = engine.tick(now:1.25)
        engine.receive(.mouseMove(time:1.25,x:1,y:0,dx:1,dy:0))
        checkFalse(engine.tick(now:1.25 + CrawlMotion.settlementDuration + 0.001).crawl.active)
    }
    func testManualCrawlContinuesThroughAmbientInputAndExplicitStopWorks() {
        let engine = AnimationEngine(now:0,expressionSeed:42)
        checkTrue(engine.startCrawl(now:0,direction:1,cancelOnInput:false))
        let before = engine.tick(now:0.1)
        engine.receive(.mouseMove(time:0.11,x:20,y:10,dx:20,dy:10))
        engine.receive(.keyDown(time:0.12,isRepeat:false,keyCode:0))
        checkEqual(engine.activity.keysHeld,1)
        let typing = engine.tick(now:0.122)
        checkTrue(typing.crawl.active); checkTrue(typing.keyboardActive)
        checkLess(typing.mouseX,0)
        engine.receive(.keyUp(time:0.125,keyCode:0))
        checkEqual(engine.activity.keysHeld,0)
        let after = engine.tick(now:0.2)
        checkTrue(after.crawl.active); checkEqual(after.state,.crawl)
        checkGreater(after.crawl.distance,before.crawl.distance)
        engine.stopCrawl(now:0.2)
        checkTrue(engine.tick(now:0.21).crawl.active)
        checkFalse(engine.tick(now:0.2 + CrawlMotion.settlementDuration + 0.001).crawl.active)
        let stoppedDistance = engine.tick(now:0.2 + CrawlMotion.settlementDuration + 0.002).crawl.distance
        checkEqual(engine.tick(now:0.2 + CrawlMotion.settlementDuration + 0.1).crawl.distance,stoppedDistance,accuracy:0.000001)
        // A subsequent default crawl must regain automatic input cancellation.
        _ = engine.tick(now:0.8)
        checkTrue(engine.startCrawl(now:1,direction:1))
        _ = engine.tick(now:1.04)
        engine.receive(.mouseMove(time:1.04,x:1,y:0,dx:1,dy:0))
        checkFalse(engine.tick(now:1.04 + CrawlMotion.settlementDuration + 0.001).crawl.active)
    }
    func testCrawlSuppressesIdleLaughDropAndRejectsBusyShoes() {
        let engine = AnimationEngine(now:0,expressionSeed:42)
        // Build idle leg blending with shoes held on by reduced motion, then
        // span both drop eligibility and idle-laugh eligibility during a crawl.
        for n in 0...440 { _ = engine.tick(now:Double(n)/10,reducedMotion:true) }
        checkTrue(engine.startCrawl(now:44,direction:1))
        for n in 0..<Int(CrawlMotion.duration * 100) {
            let now = 44+Double(n)/100, frame = engine.tick(now:now)
            checkEqual(frame.laugh,0); checkEqual(frame.state,.crawl)
            checkEqual(frame.leftShoe.phase,.halfWorn); checkEqual(frame.rightShoe.phase,.halfWorn)
            checkFalse(engine.recoverShoe(.left,now:now))
        }
        let busy = AnimationEngine(now:0,expressionSeed:42)
        var footwearBusy = false, recoverySeen = false
        for n in 0..<450 {
            let now = Double(n)/10, frame = busy.tick(now:now)
            if frame.leftShoe.phase != .halfWorn || frame.rightShoe.phase != .halfWorn {
                footwearBusy = true; checkFalse(busy.startCrawl(now:now,direction:1))
                recoverySeen = recoverySeen || frame.leftShoe.phase == .recovering || frame.rightShoe.phase == .recovering
            }
        }
        checkTrue(footwearBusy); checkTrue(recoverySeen)
    }
    func testReducedMotionCrawlHasNoTravelAndSmallOffsets() {
        let normal = CrawlMotion(), reduced = CrawlMotion()
        _ = normal.start(now:0,direction:1); _ = reduced.start(now:0,direction:1)
        for n in 0...720 {
            let now = Double(n)/100
            let a = normal.tick(now:now), b = reduced.tick(now:now,reducedMotion:true)
            checkEqual(b.distance,0); checkEqual(b.deltaX,0)
            checkEqual(b.backHandY,a.backHandY*0.12,accuracy:0.000001)
            checkEqual(b.bodyY,a.bodyY*0.12,accuracy:0.000001)
            checkEqual(b.riderBounce,a.riderBounce*0.12,accuracy:0.000001)
        }
        let switching = CrawlMotion(); _ = switching.start(now:0,direction:1)
        let before = switching.tick(now:1)
        let after = switching.tick(now:2,reducedMotion:true)
        checkEqual(after.distance,before.distance); checkEqual(after.deltaX,0)
        switching.stop(now:2)
        let reducedSettle = switching.tick(now:2.1,reducedMotion:true)
        checkLess(abs(reducedSettle.backHandX),2); checkEqual(reducedSettle.deltaX,0)
    }
}

let suite = ViolaCoreChecks()
let cases: [(String, () throws -> Void)] = [
    ("testFixedLaughIgnoresConcurrentKeyboardAndMouse", suite.testFixedLaughIgnoresConcurrentKeyboardAndMouse),
    ("testNaturalLaughTearsPrecedeWipeAndClearBeforeHandLowers", suite.testNaturalLaughTearsPrecedeWipeAndClearBeforeHandLowers),
    ("testLayeredLaughMotionRangesContinuityAndNeutralRecovery", suite.testLayeredLaughMotionRangesContinuityAndNeutralRecovery),
    ("testFrameCadenceActiveDoesNotSkipJitteredTicks", suite.testFrameCadenceActiveDoesNotSkipJitteredTicks),
    ("testFrameCadenceSlowModesKeepPhaseThroughJitter", suite.testFrameCadenceSlowModesKeepPhaseThroughJitter),
    ("testFrameCadenceEventsDoNotShiftSlowPhase", suite.testFrameCadenceEventsDoNotShiftSlowPhase),
    ("testFrameCadenceSkipsMissedSlotsAndResetsOnTransitions", suite.testFrameCadenceSkipsMissedSlotsAndResetsOnTransitions),
    ("testTypingLifecycleSingleBurstAndRelease", suite.testTypingLifecycleSingleBurstAndRelease),
    ("testRepeatDoesNotInflateHeldKeys", suite.testRepeatDoesNotInflateHeldKeys),
    ("testFrequencyExpiresAndIdleMeasuresLastRealActivity", suite.testFrequencyExpiresAndIdleMeasuresLastRealActivity),
    ("testStationaryMouseDoesNotPreventSleep", suite.testStationaryMouseDoesNotPreventSleep),
    ("testSingleTapAndRecovery", suite.testSingleTapAndRecovery),
    ("testBothClicksDepressMouseAndRecover", suite.testBothClicksDepressMouseAndRecover),
    ("testMouseDirectionIsSmoothedAndReturnsToRest", suite.testMouseDirectionIsSmoothedAndReturnsToRest),
    ("testSleepClosesEyesAndInputWakes", suite.testSleepClosesEyesAndInputWakes),
    ("testBlinkIsTransientAndNotSustained", suite.testBlinkIsTransientAndNotSustained),
    ("testFriendBlinkHasIndependentContinuousTiming", suite.testFriendBlinkHasIndependentContinuousTiming),
    ("testReducedMotionRetainsVisibleInteraction", suite.testReducedMotionRetainsVisibleInteraction),
    ("testConfigurationRoundTripAndCorruptRecovery", suite.testConfigurationRoundTripAndCorruptRecovery),
    ("testConfigurationDeskVisibilityDefaultsForOlderFiles", suite.testConfigurationDeskVisibilityDefaultsForOlderFiles),
    ("testAutomaticSleepConfigurationDefaultsAndRoundTrip", suite.testAutomaticSleepConfigurationDefaultsAndRoundTrip),
    ("testDisabledAutomaticSleepRetainsLongIdleBlinkAndBreath", suite.testDisabledAutomaticSleepRetainsLongIdleBlinkAndBreath),
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
    ("testToeClockBoundsSuspendAndRejectsInvalidDelta", suite.testToeClockBoundsSuspendAndRejectsInvalidDelta),
    ("testCrawlTravelIsIndependentOfFrameRateAndDirection", suite.testCrawlTravelIsIndependentOfFrameRateAndDirection),
    ("testCrawlContactsAlternateAndStanceCompensatesTravel", suite.testCrawlContactsAlternateAndStanceCompensatesTravel),
    ("testCrawlEntryExitAndCancellationAreSmoothAndBounded", suite.testCrawlEntryExitAndCancellationAreSmoothAndBounded),
    ("testCrawlInputCancellationAndQueuedLaugh", suite.testCrawlInputCancellationAndQueuedLaugh),
    ("testManualCrawlContinuesThroughAmbientInputAndExplicitStopWorks", suite.testManualCrawlContinuesThroughAmbientInputAndExplicitStopWorks),
    ("testCrawlSuppressesIdleLaughDropAndRejectsBusyShoes", suite.testCrawlSuppressesIdleLaughDropAndRejectsBusyShoes),
    ("testReducedMotionCrawlHasNoTravelAndSmallOffsets", suite.testReducedMotionCrawlHasNoTravelAndSmallOffsets)
]
for (name, body) in cases {
    runningCase = name
    let previousFailures = failures.count
    do { try body() } catch { fail("unexpected error: \(error)") }
    print("\(previousFailures == failures.count ? "PASS" : "FAIL") \(name)")
}
if !failures.isEmpty { for item in failures { fputs(item + "\n", stderr) }; exit(1) }
print("PASS: \(cases.count) core behavior checks")
