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
	# Optional battery-control helper; only installed if the user asks (Battery page).
	cp .build/release/pharos-battd $(DIST)/Contents/MacOS/pharos-battd
	cp Resources/Info.plist $(DIST)/Contents/Info.plist
	cp Resources/Pharos.icns $(DIST)/Contents/Resources/Pharos.icns
	codesign --force --sign - $(DIST)

install: app
	-pkill -x $(APP)
	sleep 0.5
	rm -rf /Applications/$(APP).app
	cp -R $(DIST) /Applications/
	open /Applications/$(APP).app

clean:
	rm -rf .build dist
