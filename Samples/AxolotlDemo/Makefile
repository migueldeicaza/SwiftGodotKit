.PHONY: all pck project build-macos build-ios-simulator clean

all: pck project

pck:
	./Scripts/build-pck.sh

project:
	xcodegen generate

build-macos: all
	xcodebuild -project AxolotlDemo.xcodeproj -scheme AxolotlDemo-macOS -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

build-ios-simulator: all
	xcodebuild -project AxolotlDemo.xcodeproj -scheme AxolotlDemo-iOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

clean:
	xcodebuild -project AxolotlDemo.xcodeproj -alltargets clean
