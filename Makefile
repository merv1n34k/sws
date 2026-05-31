.PHONY: setup dev build test test-all lint fmt clean run icon app install uninstall

APP_NAME    := SWS
APP_BUNDLE  := .build/$(APP_NAME).app
APP_BIN     := $(APP_BUNDLE)/Contents/MacOS/sws
APP_PLIST   := $(APP_BUNDLE)/Contents/Info.plist
APP_RES     := $(APP_BUNDLE)/Contents/Resources
APPS_DIR    := /Applications
ICONSET     := .build/AppIcon.iconset
ICON_ICNS   := .build/AppIcon.icns

setup:
	swift package resolve

dev:
	swift build && .build/debug/sws

build:
	swift build -c release

test:
	swift test

test-all:
	swift test

lint:
	@which swiftlint >/dev/null 2>&1 && swiftlint lint --quiet || echo "swiftlint not installed, skipping"

fmt:
	@which swiftformat >/dev/null 2>&1 && swiftformat Sources/ || echo "swiftformat not installed, skipping"

clean:
	swift package clean
	rm -rf .build/

run: build
	.build/release/sws

# Generates AppIcon.icns from the Swift drawing script.
icon:
	@rm -rf $(ICONSET) $(ICON_ICNS)
	@swift scripts/generate-icon.swift $(ICONSET) >/dev/null
	@iconutil -c icns $(ICONSET) -o $(ICON_ICNS)
	@rm -rf $(ICONSET)
	@echo "Built $(ICON_ICNS)"

# Builds SWS.app — a proper macOS bundle with Info.plist, the
# generated app icon, and an ad-hoc code signature. The bundle is
# what TCC (Screen Recording, etc.) tracks; without it permissions
# are invalidated on the next build.
app: build icon
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_RES)
	@cp .build/release/sws $(APP_BIN)
	@cp Resources/Info.plist $(APP_PLIST)
	@cp $(ICON_ICNS) $(APP_RES)/AppIcon.icns
	@codesign --force --deep --sign - $(APP_BUNDLE) >/dev/null
	@echo "Built $(APP_BUNDLE)"

install: app
	@rm -rf $(APPS_DIR)/$(APP_NAME).app
	@cp -R $(APP_BUNDLE) $(APPS_DIR)/
	@echo "Installed $(APPS_DIR)/$(APP_NAME).app"
	@echo "Run with: open $(APPS_DIR)/$(APP_NAME).app"

uninstall:
	@rm -rf $(APPS_DIR)/$(APP_NAME).app
	@echo "Removed $(APPS_DIR)/$(APP_NAME).app"
