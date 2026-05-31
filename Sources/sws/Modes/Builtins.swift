/// Registers the modes shipped with sws. New built-in modes are added
/// here; third-party modes can call ModeRegistry.shared.register
/// directly from their own source file.
func registerBuiltInModes() {
    ModeRegistry.shared.register(TerminalModeFactory.self)
    ModeRegistry.shared.register(TimerModeFactory.self)
    ModeRegistry.shared.register(ColorModeFactory.self)
    ModeRegistry.shared.register(GeneratorsModeFactory.self)
    ModeRegistry.shared.register(ScratchpadModeFactory.self)
    ModeRegistry.shared.register(ClipboardModeFactory.self)
    ModeRegistry.shared.register(EnDeModeFactory.self)
    // Back-compat for the brief 'oklabs' typeId — maps to 'color'.
    ModeRegistry.shared.registerAlias("oklabs", to: ColorModeFactory.typeId)
}
