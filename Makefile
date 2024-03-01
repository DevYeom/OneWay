PLATFORM_IOS = iOS Simulator,name=iPhone 15
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV
PLATFORM_VISIONOS = visionOS Simulator,name=Apple Vision Pro
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 9 (45mm)
CONFIG = debug

default: test-all

test-all:
	CONFIG=debug make test
	CONFIG=release make test

test:
	for platform in \
		"$(PLATFORM_IOS)" \
		"$(PLATFORM_MACOS)" \
		"$(PLATFORM_TVOS)" \
		"$(PLATFORM_VISIONOS)" \
		"$(PLATFORM_WATCHOS)"; \
	do \
		xcodebuild clean build test \
			-scheme OneWay \
			-configuration $(CONFIG) \
			-destination platform="$$platform" || exit 1; \
	done;

.PHONY: test-all test
