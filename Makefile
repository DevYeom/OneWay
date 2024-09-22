PLATFORM_IOS = iOS Simulator,name=iPhone 16
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV
PLATFORM_VISIONOS = visionOS Simulator,name=Apple Vision Pro
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 10 (46mm)
CONFIG = debug

default: test

build-all:
	CONFIG=debug make build
	CONFIG=release make build

build:
	for platform in \
		"$(PLATFORM_IOS)" \
		"$(PLATFORM_MACOS)" \
		"$(PLATFORM_TVOS)" \
		"$(PLATFORM_VISIONOS)" \
		"$(PLATFORM_WATCHOS)"; \
	do \
		xcodebuild clean build \
			-scheme OneWay \
			-configuration $(CONFIG) \
			-destination platform="$$platform" || exit 1; \
	done;

test:
	swift package clean
	swift test

test-swift6:
	swift package clean
	swift test -Xswiftc -swift-version -Xswiftc 6

.PHONY: build-all build test test-swift6
