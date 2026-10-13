APP = Pharos
DIST = dist/$(APP).app

.PHONY: build test app install clean icon

build:
	swift build -c release

test:
	swift run pharos-tests

# Regenerates the committed icon from Scripts/make-icon.swift (Swift + iconutil only).
icon:
	rm -rf .build/Pharos.iconset
	swift Scripts/make-icon.swift .build/Pharos.iconset
	iconutil -c icns .build/Pharos.iconset -o Resources/Pharos.icns

app: build
	rm -rf $(DIST)
	mkdir -p $(DIST)/Contents/MacOS $(DIST)/Contents/Resources
	cp .build/release/$(APP) $(DIST)/Contents/MacOS/$(APP)
	# Optional fan-control helper; only installed if the user asks (Thermal page).
	cp .build/release/pharos-fand $(DIST)/Contents/MacOS/pharos-fand
	cp Resources/Info.plist $(DIST)/Contents/Info.plist
	cp Resources/Pharos.icns $(DIST)/Contents/Resources/Pharos.icns
	codesign --force --sign - $(DIST)

install: app
	rm -rf /Applications/$(APP).app
	cp -R $(DIST) /Applications/
	open /Applications/$(APP).app

clean:
	rm -rf .build dist
