PLATFORM_IOS = iOS Simulator,name=iPhone 15
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV
PLATFORM_VISIONOS = visionOS Simulator,name=Apple Vision Pro
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 9 (45mm)
CONFIG = debug

default: test-swift

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

test-swift:
	swift test -c debug
	swift test -c release

.PHONY: build-all build test-swift
