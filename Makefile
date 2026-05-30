.PHONY: setup dev build test test-all lint fmt clean run app install uninstall

APP_NAME    := SWS
APP_BUNDLE  := .build/$(APP_NAME).app
APP_BIN     := $(APP_BUNDLE)/Contents/MacOS/sws
APP_PLIST   := $(APP_BUNDLE)/Contents/Info.plist
APPS_DIR    := /Applications

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

# Builds SWS.app — a proper macOS bundle with Info.plist and an
# ad-hoc code signature. Required so TCC (Screen Recording, etc.)
# recognizes the binary across rebuilds. Without this, granting
# permission in System Settings is invalidated on the next build.
app: build
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@cp .build/release/sws $(APP_BIN)
	@cp Resources/Info.plist $(APP_PLIST)
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
