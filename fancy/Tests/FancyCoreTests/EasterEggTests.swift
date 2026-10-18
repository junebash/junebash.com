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
      ("weather", "In Bellingham? Wind and/or rain, probably, tbh"),
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
    #expect(model.pianoKeyPressed("a"))
    #expect(recorder.sounds.last == .note(261.63))
    #expect(model.pianoKeyPressed("x"))
    #expect(model.pianoKeyPressed("A"))
    #expect(recorder.sounds.last == .note(523.26))
    #expect(!model.pianoKeyPressed("m"))
    model.closeKeyPressed()
    #expect(model.mode == .shell)
    #expect(!model.pianoKeyPressed("a"))
  }

  @Test func pianoLayout() {
    let piano = Piano()
    #expect(Piano.lower.map(\.note) == ["C", "D", "E", "F#", "G", "A", "B", "C", "D", "E", "F#"])
    #expect(Piano.upper.map(\.1.note) == ["C#", "D#", "F", "G#", "A#", "C#", "D#"])
    let fSharp = piano.frequency(of: Piano.key(for: "f")!)
    #expect(fSharp > 366 && fSharp < 369.99)
  }

  @Test func aCatWalksOnTheKeyboard() async {
    let model = recorder.model()
    model.started(at: .root)
    await model.idled()
    #expect(!model.input.isEmpty)
    #expect(!model.isCatWalking)
    #expect(!model.isTyping)
  }

  @Test func noCatWhileReading() async {
    let model = recorder.model()
    model.started(at: SitePath(["about"]))
    await model.idled()
    #expect(model.input.isEmpty)
  }
}
