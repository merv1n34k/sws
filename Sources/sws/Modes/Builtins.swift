/// Registers the modes shipped with sws. New built-in modes are added
/// here; third-party modes can call ModeRegistry.shared.register
/// directly from their own source file.
func registerBuiltInModes() {
    ModeRegistry.shared.register(TerminalModeFactory.self)
    // Populated as each built-in mode lands:
    //   ModeRegistry.shared.register(TimerModeFactory.self)
    //   ModeRegistry.shared.register(ColorModeFactory.self)
}
