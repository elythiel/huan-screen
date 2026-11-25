APP_NAME := HuanScreen
APP := build/Huan Screen.app
INSTALL_DIR := $(HOME)/Applications
SOURCES := $(wildcard Sources/HuanScreen/*.swift)
SWIFTC_FLAGS := -O -swift-version 6 -parse-as-library -framework IOKit -framework ServiceManagement
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
RELEASE_ZIP := build/$(APP_NAME)-$(VERSION).zip

.PHONY: app install uninstall release clean

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
	mkdir -p "$(APP)/Contents/MacOS"
	cp build/$(APP_NAME) "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --sign - "$(APP)"

install: app
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/Huan Screen.app"
	cp -R "$(APP)" "$(INSTALL_DIR)/"

uninstall:
	rm -rf "$(INSTALL_DIR)/Huan Screen.app"

release: app
	rm -f "$(RELEASE_ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(RELEASE_ZIP)"
	shasum -a 256 "$(RELEASE_ZIP)"

clean:
	rm -rf build
