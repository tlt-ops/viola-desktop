from pathlib import Path
root=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/source')
workspace=Path('/Users/tanlantian/Documents/ChatGPT/键鼠互动')
def save(rel,s):
 for folder in [root,workspace]:
  p=folder/rel;tmp=p.with_suffix(p.suffix+'.tmp');tmp.write_text(s);tmp.replace(p)
p='Sources/ViolaCore/Configuration.swift';s=(root/p).read_text();s=s.replace('public var sleepAfter = 60.0','public var automaticSleepEnabled = false\n    public var sleepAfter = 60.0');s=s.replace('case laughSoundEnabled, laughSoundVolume, showDesks, idleCrawlEnabled','case laughSoundEnabled, laughSoundVolume, showDesks, idleCrawlEnabled, automaticSleepEnabled');s=s.replace('        sleepAfter = try values.decodeIfPresent','        automaticSleepEnabled = try values.decodeIfPresent(Bool.self, forKey: .automaticSleepEnabled) ?? false\n        sleepAfter = try values.decodeIfPresent');save(p,s)
p='Sources/ViolaDesktop/AppDelegate.swift';s=(root/p).read_text();s=s.replace('private var sleepSlider: NSSlider?','private var sleepSlider: NSSlider?\n    private var automaticSleepButton: NSButton?');s=s.replace('config = store.load(); engine.activity.sleepDelay = config.sleepAfter','config = store.load(); applySleepPreference()');s=s.replace('width: 510, height: 600','width: 510, height: 635');s=s.replace('        let sleepRow = NSStackView();','        automaticSleepButton = NSButton(checkboxWithTitle: "闲置时自动闭眼休眠", target: self, action: #selector(toggleAutomaticSleep))\n        stack.addArrangedSubview(automaticSleepButton!)\n        let sleepRow = NSStackView();');s=s.replace('    @objc private func changeSleep(_ sender: NSSlider) { config.sleepAfter = sender.doubleValue; engine.activity.sleepDelay = config.sleepAfter; save(); refreshSettings() }','''    private func applySleepPreference() {
        engine.activity.sleepDelay = config.automaticSleepEnabled ? config.sleepAfter : .infinity
    }
    @objc private func toggleAutomaticSleep(_ sender: NSButton) {
        config.automaticSleepEnabled = sender.state == .on
        applySleepPreference(); save(); refreshSettings()
    }
    @objc private func changeSleep(_ sender: NSSlider) { config.sleepAfter = sender.doubleValue; applySleepPreference(); save(); refreshSettings() }''');s=s.replace('        sleepSlider?.doubleValue = config.sleepAfter; sleepValue?.stringValue = "\\(Int(config.sleepAfter)) 秒"','''        automaticSleepButton?.state = config.automaticSleepEnabled ? .on : .off
        sleepSlider?.isEnabled = config.automaticSleepEnabled
        sleepSlider?.doubleValue = config.sleepAfter
        sleepValue?.stringValue = config.automaticSleepEnabled ? "\\(Int(config.sleepAfter)) 秒" : "已关闭"''');save(p,s)
p='Sources/ViolaChecks/main.swift';s=(root/p).read_text();marker='    func testConfigurationBoundsAndPauseReset() {';tests='''    func testAutomaticSleepConfigurationDefaultsAndRoundTrip() throws {
        checkFalse(PetConfiguration().automaticSleepEnabled)
        let older = try JSONDecoder().decode(PetConfiguration.self,from:Data("{\\"sleepAfter\\":120}".utf8))
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
''';s=s.replace(marker,tests+marker);marker='    ("testConfigurationBoundsAndPauseReset", suite.testConfigurationBoundsAndPauseReset),';s=s.replace(marker,'    ("testAutomaticSleepConfigurationDefaultsAndRoundTrip", suite.testAutomaticSleepConfigurationDefaultsAndRoundTrip),\n    ("testDisabledAutomaticSleepRetainsLongIdleBlinkAndBreath", suite.testDisabledAutomaticSleepRetainsLongIdleBlinkAndBreath),\n'+marker);save(p,s)
