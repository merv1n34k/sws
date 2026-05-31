.PHONY: setup dev build test test-all lint fmt clean run icon app install uninstall

APP_NAME    := SWS
APP_BUNDLE  := .build/$(APP_NAME).app
APP_BIN     := $(APP_BUNDLE)/Contents/MacOS/sws
APP_PLIST   := $(APP_BUNDLE)/Contents/Info.plist
APP_RES     := $(APP_BUNDLE)/Contents/Resources
APPS_DIR    := /Applications
ICONSET     := .build/AppIcon.iconset
ICON_ICNS   := .build/AppIcon.icns
MENUBAR_DIR := .build/menubar

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

# Generated AppIcon.icns and menu-bar PNGs share a single script run.
$(ICON_ICNS) $(MENUBAR_DIR)/MenuBarIcon.png $(MENUBAR_DIR)/MenuBarIcon@2x.png: scripts/generate-icon.swift
	@rm -rf $(ICONSET) $(MENUBAR_DIR)
	@swift $< $(ICONSET) $(MENUBAR_DIR) >/dev/null
	@iconutil -c icns $(ICONSET) -o $(ICON_ICNS)
	@rm -rf $(ICONSET)
	@echo "Built $(ICON_ICNS) and menu-bar PNGs"

icon: $(ICON_ICNS)

# SWS.app rebuilds only when its inputs change. Keeping the bundle
# bytes stable across rebuilds is what makes TCC (Screen Recording)
# hold the permission grant.
$(APP_BUNDLE)/Contents/_CodeSignature/CodeResources: \
		.build/release/sws \
		Resources/Info.plist \
		$(ICON_ICNS) \
		$(MENUBAR_DIR)/MenuBarIcon.png \
		$(MENUBAR_DIR)/MenuBarIcon@2x.png
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS $(APP_RES)
	@cp .build/release/sws $(APP_BIN)
	@cp Resources/Info.plist $(APP_PLIST)
	@cp $(ICON_ICNS) $(APP_RES)/AppIcon.icns
	@cp $(MENUBAR_DIR)/MenuBarIcon.png $(APP_RES)/MenuBarIcon.png
	@cp $(MENUBAR_DIR)/MenuBarIcon@2x.png $(APP_RES)/MenuBarIcon@2x.png
	@codesign --force --deep --sign - $(APP_BUNDLE) >/dev/null
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
	@# Reset the TCC Screen Recording grant so the new build's cdhash
	@# is re-evaluated on first launch. Ad-hoc signed bundles can hold
	@# stale TCC entries when the cdhash changes; resetting here makes
	@# every install a clean slate.
	@tccutil reset ScreenCapture com.merv1n34k.sws 2>/dev/null || true
	@echo "Installed $(APPS_DIR)/$(APP_NAME).app"
	@echo "(TCC ScreenCapture reset — grant again on first launch)"
	@echo "Run with: open $(APPS_DIR)/$(APP_NAME).app"

uninstall:
	@rm -rf $(APPS_DIR)/$(APP_NAME).app
	@echo "Removed $(APPS_DIR)/$(APP_NAME).app"
