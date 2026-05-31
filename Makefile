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

# Generated AppIcon.icns is a file target; the script and its output
# are tracked so re-running `make icon` is a no-op when nothing changed.
$(ICON_ICNS): scripts/generate-icon.swift
	@rm -rf $(ICONSET)
	@swift $< $(ICONSET) >/dev/null
	@iconutil -c icns $(ICONSET) -o $@
	@rm -rf $(ICONSET)
	@echo "Built $@"

icon: $(ICON_ICNS)

# SWS.app is built only when its inputs (binary, plist, icon) are
# newer than the bundle's signed marker. Keeping the bundle bytes
# stable across rebuilds is what makes TCC (Screen Recording) hold
# the permission grant — every byte-different rebuild invalidates it.
$(APP_BUNDLE)/Contents/_CodeSignature/CodeResources: .build/release/sws Resources/Info.plist $(ICON_ICNS)
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS $(APP_RES)
	@cp .build/release/sws $(APP_BIN)
	@cp Resources/Info.plist $(APP_PLIST)
	@cp $(ICON_ICNS) $(APP_RES)/AppIcon.icns
	@codesign --force --deep --options runtime --sign - $(APP_BUNDLE) >/dev/null
	@echo "Built $(APP_BUNDLE)"

app: build $(APP_BUNDLE)/Contents/_CodeSignature/CodeResources

install: app
	@if [ -d $(APPS_DIR)/$(APP_NAME).app ]; then \
		if diff -rq $(APP_BUNDLE) $(APPS_DIR)/$(APP_NAME).app >/dev/null 2>&1; then \
			echo "Already installed and unchanged at $(APPS_DIR)/$(APP_NAME).app"; \
			exit 0; \
		fi; \
		rm -rf $(APPS_DIR)/$(APP_NAME).app; \
	fi
	@cp -R $(APP_BUNDLE) $(APPS_DIR)/
	@xattr -dr com.apple.quarantine $(APPS_DIR)/$(APP_NAME).app 2>/dev/null || true
	@echo "Installed $(APPS_DIR)/$(APP_NAME).app"
	@echo "Run with: open $(APPS_DIR)/$(APP_NAME).app"

uninstall:
	@rm -rf $(APPS_DIR)/$(APP_NAME).app
	@echo "Removed $(APPS_DIR)/$(APP_NAME).app"
