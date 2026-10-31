APP = Pharos
DIST = dist/$(APP).app
VERSION ?= 3.0.0
DMG_NAME = $(APP)-$(VERSION).dmg
DMG_PATH = dist/$(DMG_NAME)
DMG_STAGE = dist/dmg-stage

.PHONY: build test app install clean icon assets dmg

build:
	swift build -c release

test:
	swift run pharos-tests

# Regenerates the committed icons from Scripts/make-icon.swift (Swift + iconutil only):
#   Resources/Pharos.icns       light (default) icon, used everywhere
#   Resources/PharosDark.icns   dark icon for runtime Dock appearance switching
#   Resources/AppIcon.icon      Icon Composer source with Light + Dark layers for actool
icon:
	rm -rf .build/Pharos.iconset .build/PharosDark.iconset
	swift Scripts/make-icon.swift .build/Pharos.iconset light
	iconutil -c icns .build/Pharos.iconset -o Resources/Pharos.icns
	swift Scripts/make-icon.swift .build/PharosDark.iconset dark
	iconutil -c icns .build/PharosDark.iconset -o Resources/PharosDark.icns
	swift Scripts/make-icon.swift Resources/AppIcon.icon/Assets/light.png light layer
	swift Scripts/make-icon.swift Resources/AppIcon.icon/Assets/dark.png dark layer

# Compiles Resources/AppIcon.icon into Assets.car (Any + Dark appearances). Needs Xcode's actool;
# without it the bundle simply ships Pharos.icns (light) and never fails the build.
assets:
	rm -rf .build/icon-assets && mkdir -p .build/icon-assets
	@if xcrun --find actool >/dev/null 2>&1 && \
	    xcrun actool Resources/AppIcon.icon --compile .build/icon-assets --platform macosx \
	        --minimum-deployment-target 14.0 --app-icon AppIcon \
	        --output-partial-info-plist .build/icon-assets/partial.plist >/dev/null 2>&1 && \
	    test -f .build/icon-assets/Assets.car; then \
	    echo "actool: built Assets.car (light + dark icon)"; \
	else \
	    rm -rf .build/icon-assets && mkdir -p .build/icon-assets; \
	    echo "actool unavailable: shipping Pharos.icns only"; \
	fi

app: build assets
	rm -rf $(DIST)
	mkdir -p $(DIST)/Contents/MacOS $(DIST)/Contents/Resources
	cp .build/release/$(APP) $(DIST)/Contents/MacOS/$(APP)
	# Optional fan-control helper; only installed if the user asks (Thermal page).
	cp .build/release/pharos-fand $(DIST)/Contents/MacOS/pharos-fand
	# Optional battery-control helper; only installed if the user asks (Battery page).
	cp .build/release/pharos-battd $(DIST)/Contents/MacOS/pharos-battd
	cp Resources/Info.plist $(DIST)/Contents/Info.plist
	cp Resources/Pharos.icns $(DIST)/Contents/Resources/Pharos.icns
	if [ -f Resources/PharosDark.icns ]; then cp Resources/PharosDark.icns $(DIST)/Contents/Resources/PharosDark.icns; fi
	if [ -f .build/icon-assets/Assets.car ]; then cp .build/icon-assets/Assets.car $(DIST)/Contents/Resources/Assets.car; fi
	codesign --force --sign - $(DIST)

dmg: app
	rm -rf $(DMG_STAGE) $(DMG_PATH) dist/$(APP).dmg
	mkdir -p $(DMG_STAGE)
	cp -R $(DIST) $(DMG_STAGE)/
	ln -s /Applications $(DMG_STAGE)/Applications
	hdiutil create -volname "$(APP)" -srcfolder $(DMG_STAGE) -ov -format UDZO $(DMG_PATH)
	rm -rf $(DMG_STAGE)
	cp $(DMG_PATH) dist/$(APP).dmg
	shasum -a 256 $(DMG_PATH) > $(DMG_PATH).sha256
	@echo "Built $(DMG_PATH) with SHA256:"
	@cat $(DMG_PATH).sha256

install: app
	-pkill -x $(APP)
	sleep 0.5
	rm -rf /Applications/$(APP).app
	cp -R $(DIST) /Applications/
	open /Applications/$(APP).app

clean:
	rm -rf .build dist
