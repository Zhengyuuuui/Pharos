APP = UsageBar
DIST = dist/$(APP).app

.PHONY: build test app install clean

build:
	swift build -c release

test:
	swift run usagebar-tests

app: build
	rm -rf $(DIST)
	mkdir -p $(DIST)/Contents/MacOS $(DIST)/Contents/Resources
	cp .build/release/$(APP) $(DIST)/Contents/MacOS/$(APP)
	cp Resources/Info.plist $(DIST)/Contents/Info.plist
	cp Resources/UsageBar.icns $(DIST)/Contents/Resources/UsageBar.icns
	codesign --force --sign - $(DIST)

install: app
	rm -rf /Applications/$(APP).app
	cp -R $(DIST) /Applications/
	open /Applications/$(APP).app

clean:
	rm -rf .build dist
