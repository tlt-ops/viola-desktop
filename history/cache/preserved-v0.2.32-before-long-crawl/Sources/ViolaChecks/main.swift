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
        checkEqual(CrawlMotion.duration,0.36,accuracy:0.000001)
        checkEqual(CrawlMotion.maximumTravel,149.6,accuracy:0.000001)
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
    }
    func testCrawlContactsAlternateAndStanceCompensatesTravel() {
        let gait = CrawlMotion(); checkTrue(gait.start(now:0,direction:1))
        // At phase 0.8 the back palm/front knee swing; half a cycle later
        // the front palm/back knee swing. The other diagonal stays grounded.
        let backSwing = gait.tick(now:0.072)
        checkGreater(backSwing.backHandY,10); checkEqual(backSwing.frontHandY,0)
        checkGreater(backSwing.frontKneeY,5); checkEqual(backSwing.backKneeY,0)
        let frontSwing = gait.tick(now:0.117)
        checkGreater(frontSwing.frontHandY,10); checkEqual(frontSwing.backHandY,0)
        checkGreater(frontSwing.backKneeY,5); checkEqual(frontSwing.frontKneeY,0)
        let a = gait.tick(now:0.189), b = gait.tick(now:0.207)
        checkEqual(a.backHandY,0); checkEqual(b.backHandY,0)
        checkEqual(b.backHandX-a.backHandX,-b.deltaX,accuracy:0.000001)
        checkEqual(b.phase-a.phase,0.2,accuracy:0.000001)
    }
    func testCrawlEntryExitAndCancellationAreSmoothAndBounded() {
        let gait = CrawlMotion(); _ = gait.start(now:0,direction:1)
        var previous = gait.tick(now:0), previousWeight = 0.0
        for n in 1...Int(CrawlMotion.duration * 2000) {
            let frame = gait.tick(now:Double(n)/2000)
            checkTrue(frame.weight >= 0 && frame.weight <= 1)
            checkLess(abs(frame.weight-previousWeight),0.05)
            checkLess(abs(frame.riderBounce),1.50001); checkLess(abs(frame.bodyRoll),0.01801)
            checkLess(abs(frame.backHandX-previous.backHandX),1)
            checkLess(abs(frame.frontHandX-previous.frontHandX),1)
            previous = frame; previousWeight = frame.weight
        }
        checkEqual(previous.weight,0); checkFalse(previous.active)
        _ = gait.start(now:10,direction:-1)
        let moving = gait.tick(now:10.072)
        gait.stop(now:10.072)
        let unchanged = gait.tick(now:10.072)
        checkEqual(unchanged.backHandY,moving.backHandY,accuracy:0.000001)
        let halfway = gait.tick(now:10.085)
        checkEqual(halfway.weight,moving.weight*0.5,accuracy:0.000001)
        checkEqual(halfway.distance,moving.distance,accuracy:0.000001); checkEqual(halfway.deltaX,0)
        let settled = gait.tick(now:10.099)
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
        checkFalse(engine.tick(now:0.167).crawl.active)
        engine.receive(.keyUp(time:0.168,keyCode:0)); _ = engine.tick(now:0.8)
        checkTrue(engine.startCrawl(now:0.8,direction:-1)); _ = engine.tick(now:0.88)
        checkFalse(engine.startLaugh(now:0.88)); checkTrue(engine.isCrawling)
        let settling = engine.tick(now:0.89); checkEqual(settling.laugh,0)
        let laughing = engine.tick(now:0.907)
        checkFalse(laughing.crawl.active); checkEqual(laughing.state,.laugh)
        checkFalse(engine.startCrawl(now:0.907,direction:1))
        engine.reset(now:1.2); checkFalse(engine.isCrawling)
        checkEqual(engine.tick(now:1.2).crawl.distance,0)
        checkTrue(engine.startCrawl(now:1.2,direction:1)); _ = engine.tick(now:1.25)
        engine.receive(.mouseMove(time:1.25,x:1,y:0,dx:1,dy:0))
        checkFalse(engine.tick(now:1.277).crawl.active)
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
        checkFalse(engine.tick(now:0.227).crawl.active)
        let stoppedDistance = engine.tick(now:0.23).crawl.distance
        checkEqual(engine.tick(now:0.25).crawl.distance,stoppedDistance,accuracy:0.000001)
        // A subsequent default crawl must regain automatic input cancellation.
        _ = engine.tick(now:0.8)
        checkTrue(engine.startCrawl(now:1,direction:1))
        _ = engine.tick(now:1.04)
        engine.receive(.mouseMove(time:1.04,x:1,y:0,dx:1,dy:0))
        checkFalse(engine.tick(now:1.067).crawl.active)
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
