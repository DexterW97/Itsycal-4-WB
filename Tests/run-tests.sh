#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
repo_root="$PWD"
test_build="${TMPDIR:-/tmp}/itsycal-calendar-tests"
mkdir -p "$test_build/snapshots"
src="$repo_root/Itsycal"
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path="$test_build/ModuleCache" -Werror -Wno-deprecated-declarations \
  -I "$src" -I "$src/MoCode" -I "$src/MoCode/MoCalendar" -I "$src/Birthdays" \
  -framework Cocoa -framework QuartzCore -framework EventKit -framework UserNotifications \
  Tests/CalendarTests.m \
  "$src/MoCode/MoDate.m" "$src/MoCode/MoCalendar/MoLunarDate.m" \
  "$src/MoCode/MoCalendar/MoCalendar.m" "$src/MoCode/MoCalendar/MoCalCell.m" \
  "$src/MoCode/MoCalendar/MoCalGrid.m" "$src/MoCode/MoCalendar/MoCalToolTipWC.m" \
  "$src/MoCode/MoButton.m" "$src/MoCode/MoVFLHelper.m" "$src/Sizer.m" "$src/Themer.m" "$src/ItsycalWindow.m" "$src/MoCode/MoThemeView.m" \
  "$src/Birthdays/BirthdayStore.m" "$src/Birthdays/BirthdaysVC.m" "$src/Birthdays/BirthdayNotifications.m" \
  "$src/TooltipViewController.m" "$src/AgendaViewController.m" "$src/EventCenter.m" "$src/Itsycal.m" "$src/MoUtils.m" \
  "$src/MoCode/MoTableView.m" "$src/MoCode/MoPopover.m" \
  -o "$test_build/calendar-tests"
if [[ "${1:-}" == "--ui" ]]; then
  "$test_build/calendar-tests" "$repo_root" "$test_build/snapshots" -AppleLocale zh_CN -AppleLanguages '(zh-Hans)'
else
  "$test_build/calendar-tests"
fi

xcrun clang -fobjc-arc -fmodules -fmodules-cache-path="$test_build/ModuleCache" -Werror \
  -I "$src/MoCode" -I "$src/Birthdays" -framework Foundation -framework UserNotifications \
  Tests/BirthdayTests.m "$src/Birthdays/BirthdayStore.m" "$src/MoCode/MoDate.m" \
  -o "$test_build/birthday-tests"
"$test_build/birthday-tests"
