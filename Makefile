APP = Pharos
DIST = dist/$(APP).app

.PHONY: build test app install clean icon assets

build:
	swift build -c release

test:
	swift run pharos-tests

# Regenerates the committed icons from Scripts/make-icon.swift (Swift + iconutil only):
#   Resources/Pharos.icns       light (default) icon, used everywhere
#   Resources/AppIcon.icon      Icon Composer source with Light + Dark layers for actool
icon:
	rm -rf .build/Pharos.iconset
	swift Scripts/make-icon.swift .build/Pharos.iconset light
	iconutil -c icns .build/Pharos.iconset -o Resources/Pharos.icns
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
	if [ -f .build/icon-assets/Assets.car ]; then cp .build/icon-assets/Assets.car $(DIST)/Contents/Resources/Assets.car; fi
	codesign --force --sign - $(DIST)

install: app
	-pkill -x $(APP)
	sleep 0.5
	rm -rf /Applications/$(APP).app
	cp -R $(DIST) /Applications/
	open /Applications/$(APP).app

clean:
	rm -rf .build dist
