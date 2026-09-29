#!/bin/bash
# Compiles the pure parsing code + ParserTests.swift into a CLI and runs every check. No Xcode target needed.
set -euo pipefail
cd "$(dirname "$0")"
APP=../BillFixer
OUT=$(mktemp -d)
cat > "$OUT/Checks.swift" << 'M'
@main struct Checks { static func main() { checkMoneyParsing(); checkBillParser(); checkEOBParser(); checkDates(); print("✓ all parser checks passed") } }
M
sed -e 's/^#if canImport(Testing)/#if false/' ParserTests.swift > "$OUT/ParserTests.swift"
xcrun swiftc -swift-version 5 -parse-as-library -o "$OUT/checks" \
  $APP/Core/Models/Money.swift $APP/Core/Models/Requests.swift $APP/Core/Utils/DateHelpers.swift \
  $APP/Core/Services/Capture/OCRModels.swift $APP/Core/Services/Capture/TextPatterns.swift \
  $APP/Core/Services/Capture/Drafts.swift $APP/Core/Services/Capture/BillParser.swift $APP/Core/Services/Capture/EOBParser.swift \
  "$OUT/ParserTests.swift" "$OUT/Checks.swift" 2>&1 | grep -v warning || true
"$OUT/checks"
