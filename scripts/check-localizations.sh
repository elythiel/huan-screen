#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

used=$(grep -ohE 'localized\("[^"]+"' Sources/HuanScreen/*.swift | sed -E 's/^localized\("(.*)"$/\1/' | sort -u)
status=0

for strings in Resources/*.lproj/Localizable.strings; do
    plutil -lint -s "$strings"
    defined=$(plutil -convert json -o - "$strings" | python3 -I -c 'import json, sys; print("\n".join(sorted(json.load(sys.stdin))))')

    missing=$(comm -23 <(echo "$used") <(echo "$defined"))
    unused=$(comm -13 <(echo "$used") <(echo "$defined"))

    if [ -n "$missing" ]; then
        echo "Missing in $strings:"
        echo "$missing" | sed 's/^/  /'
        status=1
    fi
    if [ -n "$unused" ]; then
        echo "Unused in $strings:"
        echo "$unused" | sed 's/^/  /'
        status=1
    fi
done

[ "$status" -eq 0 ] && echo "Localizations OK ($(echo "$used" | wc -l | tr -d ' ') keys)"
exit "$status"
