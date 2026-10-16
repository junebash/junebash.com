import JavaScriptEventLoop

JavaScriptEventLoop.installGlobalExecutor()

let app = App()
Task {
  await app.run()
}
