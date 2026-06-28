.PHONY: gen open build-ios build-macos icon archive validate upload dist clean

PROJECT      = apps/apple/SmartSketcher.xcodeproj
ARCHIVE      = build/SmartSketcher.xcarchive
EXPORT_DIR   = build/export
EXPORT_OPTS  = build/ExportOptions.plist
TEAM_ID      = ND3675584E
# Set via environment or override: make upload API_KEY=XXX API_ISSUER=YYY
API_KEY      ?=
API_ISSUER   ?=

# Generate the Xcode project from apps/apple/project.yml (requires xcodegen).
# Install: brew install xcodegen
gen:
	cd apps/apple && xcodegen generate

# Open the Xcode project (run gen first if the .xcodeproj doesn't exist).
open:
	open $(PROJECT)

# CI / headless builds (no signing)
build-ios:
	xcodebuild -project $(PROJECT) -scheme SmartSketcher-iOS \
	  -destination 'generic/platform=iOS' \
	  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
	  build

build-macos:
	xcodebuild -project $(PROJECT) -scheme SmartSketcher-macOS \
	  -destination 'platform=macOS' \
	  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
	  build

# Regenerate the icon from source (requires venv with pillow).
icon:
	python3 scripts/make_icon.py

# Archive, export, validate, and upload the macOS app to App Store Connect.
# Requires: API_KEY and API_ISSUER env vars, and
#   ~/.appstoreconnect/private_keys/AuthKey_<API_KEY>.p8
archive:
	@mkdir -p build
	@printf '<?xml version="1.0" encoding="UTF-8"?>\n\
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n\
<plist version="1.0"><dict>\n\
  <key>method</key><string>app-store-connect</string>\n\
  <key>teamID</key><string>$(TEAM_ID)</string>\n\
</dict></plist>\n' > $(EXPORT_OPTS)
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme SmartSketcher-macOS \
	  -configuration Release \
	  -archivePath $(ARCHIVE) \
	  archive
	xcodebuild -exportArchive \
	  -archivePath $(ARCHIVE) \
	  -exportPath $(EXPORT_DIR) \
	  -exportOptionsPlist $(EXPORT_OPTS)

# Direct distribution: Developer ID export + notarize + staple → build/dist/smART Sketcher.app
DIST_DIR         = build/dist
DIST_EXPORT_OPTS = build/ExportOptions-devid.plist

dist:
	@mkdir -p build
	@printf '<?xml version="1.0" encoding="UTF-8"?>\n\
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n\
<plist version="1.0"><dict>\n\
  <key>method</key><string>developer-id</string>\n\
  <key>teamID</key><string>$(TEAM_ID)</string>\n\
  <key>signingStyle</key><string>automatic</string>\n\
</dict></plist>\n' > $(DIST_EXPORT_OPTS)
	@[ -n "$(API_KEY)" ]    || (echo "Error: API_KEY is not set";    exit 1)
	@[ -n "$(API_ISSUER)" ] || (echo "Error: API_ISSUER is not set"; exit 1)
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme SmartSketcher-macOS \
	  -configuration Release \
	  -archivePath $(ARCHIVE) \
	  archive
	xcodebuild -exportArchive \
	  -archivePath $(ARCHIVE) \
	  -exportPath $(DIST_DIR) \
	  -exportOptionsPlist $(DIST_EXPORT_OPTS)
	ditto -c -k --sequesterRsrc --keepParent \
	  "$(DIST_DIR)/smART Sketcher.app" \
	  "$(DIST_DIR)/smART Sketcher.zip"
	xcrun notarytool submit "$(DIST_DIR)/smART Sketcher.zip" \
	  --key ~/.appstoreconnect/private_keys/AuthKey_$(API_KEY).p8 \
	  --key-id $(API_KEY) \
	  --issuer $(API_ISSUER) \
	  --wait
	xcrun stapler staple "$(DIST_DIR)/smART Sketcher.app"
	@rm -f "$(DIST_DIR)/smART Sketcher.zip"
	@echo "✓ Ready to distribute: $(DIST_DIR)/smART Sketcher.app"

validate: $(EXPORT_DIR)
	@[ -n "$(API_KEY)" ] || (echo "Error: API_KEY is not set"; exit 1)
	@[ -n "$(API_ISSUER)" ] || (echo "Error: API_ISSUER is not set"; exit 1)
	xcrun altool --validate-app \
	  -f "$(EXPORT_DIR)/smART Sketcher.pkg" \
	  -t osx \
	  --apiKey $(API_KEY) \
	  --apiIssuer $(API_ISSUER)

upload: $(EXPORT_DIR)
	@[ -n "$(API_KEY)" ] || (echo "Error: API_KEY is not set"; exit 1)
	@[ -n "$(API_ISSUER)" ] || (echo "Error: API_ISSUER is not set"; exit 1)
	xcrun altool --upload-app \
	  -f "$(EXPORT_DIR)/smART Sketcher.pkg" \
	  -t osx \
	  --apiKey $(API_KEY) \
	  --apiIssuer $(API_ISSUER)

clean:
	rm -rf build \
	       apps/apple/SmartSketcher.xcodeproj \
	       apps/apple/SmartSketcher/Info-iOS.plist \
	       apps/apple/SmartSketcher/Info-macOS.plist
