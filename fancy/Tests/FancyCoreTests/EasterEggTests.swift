import Testing

@testable import FancyCore

struct EasterEggTests {
  let recorder = Recorder()

  func run(_ model: AppModel, _ line: String) {
    model.inputChanged(line)
    model.returnKeyPressed()
  }

  @Test func oneLiners() {
    let model = recorder.model()
    model.started(at: .root)
    let machine = "What kinda machine do you think we're running here?"
    for (line, reply) in [
      ("dog", Pets.dog),
      ("weather", "in Bellingham? idk wind and/or rain probably"),
      ("import Foundation", machine),
      ("swift build", machine),
      ("swiftc main.swift", machine),
      ("xcodebuild -scheme App", "lmao"),
      ("nano", "nano: did you mean vim?"),
      ("vim", "vim: did you mean nano?"),
    ] {
      run(model, line)
      #expect(model.output.last?.content == .text(reply), "\(line)")
    }
    run(model, "import UIKit")
    #expect(model.output.last?.content == .text("import: command not found. try 'help'.", tone: .error))
  }

  @Test func bareCatPrintsACatButCatStillReads() {
    let model = recorder.model()
    model.started(at: .root)
    run(model, "cat")
    guard case .text(let art, _) = model.output.last?.content else {
      Issue.record("expected a cat")
      return
    }
    #expect(Pets.cats.contains(art))
    run(model, "cat about")
    #expect(model.pager?.path == SitePath(["about"]))
  }

  @Test func fortuneDealsEveryLineBeforeRepeating() {
    let model = recorder.model()
    model.started(at: .root)
    var dealt: [Fortune] = []
    for _ in Fortune.all {
      run(model, "fortune")
      guard case .fortune(let fortune) = model.output.last?.content else {
        Issue.record("expected a fortune")
        return
      }
      dealt.append(fortune)
    }
    #expect(Set(dealt.map(\.text)) == Set(Fortune.all.map(\.text)))
  }

  @Test func emacsHangsThenRunsOutOfMemory() async {
    let model = recorder.model()
    model.started(at: .root)
    run(model, "emacs")
    #expect(model.mode == .waiting)
    model.inputChanged("ls")
    #expect(model.input == "")
    await Task.yield()
    #expect(model.mode == .shell)
    #expect(model.output.last?.content == .text("out of memory", tone: .error))
  }

  @Test func controlCBreaksTheHang() async {
    let model = recorder.model()
    model.started(at: .root)
    run(model, "emacs")
    model.interruptPressed()
    #expect(model.mode == .shell)
    await Task.yield()
    #expect(model.output.last?.content == .text("^C"))
  }

  @Test func sittingEndsWhenYouMove() {
    let model = recorder.model()
    model.started(at: SitePath(["posts"]))
    run(model, "sit")
    #expect(model.mode == .sitting)
    #expect(recorder.sounds.last == .bell)
    model.stirred()
    #expect(model.mode == .shell)
    #expect(model.cwd == SitePath(["posts"]))
    #expect(model.output.last?.content == .text("you moved. that's fine. begin again.", tone: .dim))
  }

  @Test func pianoPlaysEvenWithSoundOff() {
    let model = recorder.model(isSoundOn: false)
    model.started(at: .root)
    run(model, "piano")
    #expect(model.pianoKeyPressed(at: "KeyA"))
    #expect(recorder.sounds.last == .note(261.63))
    #expect(model.pianoKeyPressed(at: Piano.octaveUp))
    #expect(model.pianoKeyPressed(at: "KeyA"))
    #expect(recorder.sounds.last == .note(523.26))
    #expect(!model.pianoKeyPressed(at: "KeyM"))
    model.closeKeyPressed()
    #expect(model.mode == .shell)
    #expect(!model.pianoKeyPressed(at: "KeyA"))
  }

  @Test func pianoLayout() {
    #expect(Piano.lower.map(\.note) == ["C", "D", "E", "F", "G", "A", "B", "C", "D", "E", "F"])
    #expect(Piano.upper.map(\.1.note) == ["C#", "D#", "F#", "G#", "A#", "C#", "D#"])
    // Each black key sits just right of the white key a semitone below it, and nowhere else.
    for (slot, key) in Piano.upper {
      #expect(Piano.lower[slot].semitone + 1 == key.semitone)
    }
    #expect(Piano.upper.map(\.1.code) == ["KeyW", "KeyE", "KeyT", "KeyY", "KeyU", "KeyO", "KeyP"])
  }

  @Test func everyLayoutCoversEveryKey() {
    for layout in KeyboardLayout.known {
      #expect(layout.count == KeyboardLayout.codes.joined().count)
    }
  }

  @Test func onePressGivesAwayTheLayout() {
    var layout = KeyboardLayout()
    #expect(layout.label(for: "KeyS") == "s")
    // Typing "p" on Dvorak hits the physical R.
    let changed = layout.learn(code: "KeyR", typed: "p")
    #expect(changed)
    #expect(Piano.lower.map { layout.label(for: $0.code)! } == ["a", "o", "e", "u", "i", "d", "h", "t", "n", "s", "-"])
    #expect(Piano.upper.map { layout.label(for: $0.1.code)! } == [",", ".", "y", "f", "g", "r", "l"])
    #expect(layout.label(for: Piano.octaveDown) == ";")
  }

  @Test func anUnknownLayoutKeepsWhatItLearned() {
    var layout = KeyboardLayout()
    _ = layout.learn(code: "KeyA", typed: "ж")
    #expect(layout.label(for: "KeyA") == "ж")
    #expect(layout.label(for: "KeyS") == nil)
    let learnedDeadKey = layout.learn(code: "KeyS", typed: "Dead")
    #expect(!learnedDeadKey)
  }

  @Test func aCatFindsTheKeyboardAfterFiveQuietMinutes() async {
    let model = recorder.model()
    model.started(at: .root)
    recorder.now = AppModel.catPatience - 1
    await model.clockTicked()
    #expect(model.input.isEmpty)

    recorder.now = AppModel.catPatience
    await model.clockTicked()
    let prints = model.input
    #expect(!prints.isEmpty)
    #expect(!model.isCatWalking)
    #expect(!model.isTyping)
  }

  @Test func theCatComesOncePerQuietStretch() async {
    let model = recorder.model()
    model.started(at: .root)
    recorder.now = AppModel.catPatience
    await model.clockTicked()
    let prints = model.input
    recorder.now += AppModel.catPatience * 3
    await model.clockTicked()
    #expect(model.input == prints)

    model.userActed()
    recorder.now += AppModel.catPatience - 1
    await model.clockTicked()
    #expect(model.input == prints)
    recorder.now += 1
    await model.clockTicked()
    #expect(model.input.count > prints.count)
  }

  @Test func activityKeepsTheCatAway() async {
    let model = recorder.model()
    model.started(at: .root)
    recorder.now = AppModel.catPatience - 1
    model.userActed()
    recorder.now += AppModel.catPatience - 1
    await model.clockTicked()
    #expect(model.input.isEmpty)
  }

  @Test func noCatWhileReadingButItWaitsForYou() async {
    let model = recorder.model()
    model.started(at: SitePath(["about"]))
    recorder.now = AppModel.catPatience
    await model.clockTicked()
    #expect(model.input.isEmpty)
    model.pagerDismissed()
    await model.clockTicked()
    #expect(!model.input.isEmpty)
  }

  @Test func konamiCodeGrantsLives() {
    let model = recorder.model()
    model.started(at: .root)
    // A stray key and an extra up first: only the last ten keys count.
    for key in ["x", "ArrowUp"] + AppModel.konamiCode.dropLast() {
      #expect(!model.keyPressed(key))
    }
    model.inputChanged("b")
    #expect(model.keyPressed("A"))
    #expect(model.input == "")
    #expect(model.output.last?.content == .text("LIVES += 30"))
    #expect(recorder.sounds.last == .powerUp)
  }
}
