SWIFTGODOT ?= ../../SwiftGodot
GODOT ?= ../../godot
OUTPUT ?= ../build
GODOT_REPO ?= migueldeicaza/godot

.PHONY: all package release-payloads debug-payloads zip check-version publish-release release

all: package

package:
	bash -x make-libgodot.xcframework $(SWIFTGODOT) $(GODOT) $(OUTPUT)

release-payloads:
	bash -x make-libgodot.xcframework --build --configuration release --zip $(SWIFTGODOT) $(GODOT) $(OUTPUT)

debug-payloads:
	bash -x make-libgodot.xcframework --build --configuration debug --zip $(SWIFTGODOT) $(GODOT) $(OUTPUT)

zip:
	bash -x make-libgodot.xcframework --configuration release --zip $(SWIFTGODOT) $(GODOT) $(OUTPUT)

check-version:
	@test -n "$(VERSION)" || (echo "usage: make publish-release VERSION=v4.6.x"; exit 1)

publish-release: check-version
	bash -x publish-libgodot-release "$(VERSION)" "$(GODOT)" "$(OUTPUT)" ../Package.swift "$(GODOT_REPO)"

release: check-version
	$(MAKE) release-payloads SWIFTGODOT="$(SWIFTGODOT)" GODOT="$(GODOT)" OUTPUT="$(OUTPUT)"
	$(MAKE) publish-release VERSION="$(VERSION)" GODOT="$(GODOT)" OUTPUT="$(OUTPUT)" GODOT_REPO="$(GODOT_REPO)"
