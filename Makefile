APP_NAME := HuanScreen
APP := build/Huan Screen.app
INSTALL_DIR := /Applications
SOURCES := $(wildcard Sources/HuanScreen/*.swift)
SWIFTC_FLAGS := -O -swift-version 6 -parse-as-library -framework IOKit -framework ServiceManagement -framework CryptoKit
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
RELEASE_ZIP := build/$(APP_NAME)-$(VERSION).zip

.PHONY: app icon check-localizations install uninstall release bump clean

build/$(APP_NAME)-arm64: $(SOURCES)
	mkdir -p build
	swiftc $(SWIFTC_FLAGS) -target arm64-apple-macos13.0 $(SOURCES) -o $@

build/$(APP_NAME)-x86_64: $(SOURCES)
	mkdir -p build
	swiftc $(SWIFTC_FLAGS) -target x86_64-apple-macos13.0 $(SOURCES) -o $@

build/$(APP_NAME): build/$(APP_NAME)-arm64 build/$(APP_NAME)-x86_64
	lipo -create $^ -output $@

app: build/$(APP_NAME)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp build/$(APP_NAME) "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	cp -R Resources/*.lproj "$(APP)/Contents/Resources/"
	codesign --force --sign - "$(APP)"

icon:
	mkdir -p build/AppIcon.iconset
	swift scripts/make-icon.swift build/AppIcon-1024.png
	for size in 16 32 128 256 512; do \
		sips -z $$size $$size build/AppIcon-1024.png --out build/AppIcon.iconset/icon_$${size}x$${size}.png >/dev/null; \
		sips -z $$((size * 2)) $$((size * 2)) build/AppIcon-1024.png --out build/AppIcon.iconset/icon_$${size}x$${size}@2x.png >/dev/null; \
	done
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns

check-localizations:
	scripts/check-localizations.sh

install: app
	osascript -e 'quit app id "io.github.elythiel.huan-screen"' 2>/dev/null || true
	@for i in $$(seq 50); do pgrep -x $(APP_NAME) >/dev/null || break; sleep 0.1; done
	rm -rf "$(INSTALL_DIR)/Huan Screen.app"
	cp -R "$(APP)" "$(INSTALL_DIR)/"
	open "$(INSTALL_DIR)/Huan Screen.app"

uninstall:
	rm -rf "$(INSTALL_DIR)/Huan Screen.app"

release: app
	rm -f "$(RELEASE_ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(RELEASE_ZIP)"
	shasum -a 256 "$(RELEASE_ZIP)"

bump:
	@test -n "$(V)" || { echo "Usage: make bump V=x.y.z"; exit 1; }
	@echo "$(V)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "Invalid version: $(V) (expected x.y.z)"; exit 1; }
	@test "$(V)" != "$(VERSION)" || { echo "Already at version $(V)"; exit 1; }
	@! git rev-parse --quiet --verify "refs/tags/v$(V)" >/dev/null || { echo "Tag v$(V) already exists"; exit 1; }
	@BUILD=$$(( $$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Info.plist) + 1 )); \
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(V)" -c "Set :CFBundleVersion $$BUILD" Resources/Info.plist && \
	git commit --quiet -m "🔖 chore: version $(V)" -- Resources/Info.plist && \
	echo "Version $(V) (build $$BUILD) committed."
	@git tag -a "v$(V)" -e -m "v$(V)" || { echo "Tag not created. Run: git tag -a v$(V)"; exit 1; }
	@echo "Tag v$(V) created. Publish with: git push && git push origin v$(V)"

clean:
	rm -rf build
