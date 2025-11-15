PLATFORM_IOS = iOS Simulator,name=iPhone 17
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV
PLATFORM_VISIONOS = visionOS Simulator,name=Apple Vision Pro # Temporarily disabling the visionOS simulator in GitHub Actions.
PLATFORM_VISIONOS = visionOS Simulator,name=Apple Vision Pro
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 11 (46mm)
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

build-swift:
	swift build

.PHONY: build-all build test build-swift
