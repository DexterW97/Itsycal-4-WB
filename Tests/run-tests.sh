#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
repo_root="$PWD"
test_build="${TMPDIR:-/tmp}/itsycal-calendar-tests"
mkdir -p "$test_build/snapshots"
src="$repo_root/Itsycal"
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path="$test_build/ModuleCache" -Werror -Wno-deprecated-declarations \
  -I "$src" -I "$src/MoCode" -I "$src/MoCode/MoCalendar" \
  -framework Cocoa -framework QuartzCore -framework EventKit \
  Tests/CalendarTests.m \
  "$src/MoCode/MoDate.m" "$src/MoCode/MoCalendar/MoLunarDate.m" \
  "$src/MoCode/MoCalendar/MoCalendar.m" "$src/MoCode/MoCalendar/MoCalCell.m" \
  "$src/MoCode/MoCalendar/MoCalGrid.m" "$src/MoCode/MoCalendar/MoCalToolTipWC.m" \
  "$src/MoCode/MoButton.m" "$src/MoCode/MoVFLHelper.m" "$src/Sizer.m" "$src/Themer.m" "$src/ItsycalWindow.m" \
  -o "$test_build/calendar-tests"
if [[ "${1:-}" == "--ui" ]]; then
  "$test_build/calendar-tests" "$repo_root" "$test_build/snapshots" -AppleLocale zh_CN -AppleLanguages '(zh-Hans)'
else
  "$test_build/calendar-tests"
fi
