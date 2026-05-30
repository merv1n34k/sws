/// Registers the modes shipped with sws. New built-in modes are added
/// here; third-party modes can call ModeRegistry.shared.register
/// directly from their own source file.
func registerBuiltInModes() {
    ModeRegistry.shared.register(TerminalModeFactory.self)
    ModeRegistry.shared.register(TimerModeFactory.self)
    ModeRegistry.shared.register(OklabsModeFactory.self)
    // Back-compat: configs that still say "color" map to oklabs.
    ModeRegistry.shared.registerAlias("color", to: OklabsModeFactory.typeId)
}
