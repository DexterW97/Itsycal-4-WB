#import <Cocoa/Cocoa.h>
#import "MoLunarDate.h"
#import "MoCalendar.h"
#import "MoCalGrid.h"
#import "MoCalCell.h"
#import "MoButton.h"
#import "Sizer.h"
#import "Themer.h"
#import "ItsycalWindow.h"

static void Check(BOOL ok, NSString *message) {
    if (!ok) { NSLog(@"FAIL: %@", message); exit(1); }
}

static void CheckLunar(NSInteger year, NSInteger month, NSInteger day, NSString *expected) {
    NSString *actual = MoLunarDateLabel(MakeDate(year, month - 1, day));
    Check([actual isEqual:expected], [NSString stringWithFormat:@"%ld-%ld-%ld: %@ != %@", year, month, day, actual, expected]);
}

static void TestLunar(void) {
    CheckLunar(2026, 10, 1, @"廿一");
    CheckLunar(2026, 10, 10, @"九月");
    CheckLunar(2026, 10, 18, @"重阳");
    CheckLunar(2026, 10, 27, @"十八");
    CheckLunar(2026, 2, 16, @"除夕");
    CheckLunar(2026, 2, 17, @"春节");
    CheckLunar(2026, 3, 3, @"元宵");
    CheckLunar(2026, 6, 19, @"端午");
    CheckLunar(2026, 9, 25, @"中秋");
    CheckLunar(2025, 7, 25, @"闰六月");
    CheckLunar(2023, 3, 22, @"闰二月");
    CheckLunar(2022, 1, 31, @"除夕"); // lunar December has only 29 days
    Check(MoLunarDateLabel((MoDate){2026, 1, 30, NO_JULIAN}).length == 0, @"Invalid Gregorian date");
    NSTimeZone *originalZone = NSTimeZone.defaultTimeZone;
    for (NSString *zone in @[@"America/Los_Angeles", @"Pacific/Kiritimati", @"Asia/Shanghai"]) {
        [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneWithName:zone]];
        CheckLunar(2026, 10, 27, @"十八");
    }
    [NSTimeZone setDefaultTimeZone:originalZone];
    NSLog(@"PASS: lunar dates, festivals, leap months, year boundary, time zones");
}

static void LoadImages(NSString *sourceRoot) {
    for (NSString *name in @[@"btnPrev", @"btnPrevAlt", @"btnToday", @"btnTodayAlt", @"btnNext", @"btnNextAlt", @"btnPin", @"btnPinAlt", @"btnOpt"]) {
        NSString *path = [sourceRoot stringByAppendingFormat:@"/Itsycal/Images.xcassets/%@.imageset/%@.png", name, name];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
        Check(image != nil, path);
        [image setName:name];
    }
}

static void SaveSnapshot(NSView *view, NSString *path) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
        pixelsWide:ceil(NSWidth(view.bounds) * 2) pixelsHigh:ceil(NSHeight(view.bounds) * 2)
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    bitmap.size = view.bounds.size;
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    Check([[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES], @"Write preview");
}

static void TestLayout(NSString *sourceRoot, NSString *snapshots) {
    [NSApplication sharedApplication];
    [Sizer shared];
    [Themer shared];
    LoadImages(sourceRoot);
    for (NSInteger size = 0; size <= 2; size++) {
        SizePref.sizePreference = size;
        for (NSNumber *weeks in @[@NO, @YES]) {
            MoCalendar *cal = [MoCalendar new];
            MoButton *pin = [MoButton new];
            pin.image = [NSImage imageNamed:@"btnPin"];
            MoButton *options = [MoButton new];
            options.image = [NSImage imageNamed:@"btnOpt"];
            [cal installHeaderPinButton:pin optionsButton:options];
            cal.todayDate = MakeDate(2026, 9, 27);
            cal.selectedDate = cal.todayDate;
            cal.weekStartDOW = 1;
            cal.showWeeks = weeks.boolValue;
            cal.highlightedDOWs = DOWMaskSat | DOWMaskSun;
            ItsycalWindow *window = [ItsycalWindow new];
            [window setContentSize:NSMakeSize(500, 600)];
            NSLayoutGuide *safeArea = window.contentView.safeAreaLayoutGuide;
            cal.translatesAutoresizingMaskIntoConstraints = NO;
            [window.contentView addSubview:cal];
            [NSLayoutConstraint activateConstraints:@[
                [cal.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:2],
                [cal.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-2],
                [cal.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
                [cal.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
            ]];
            [window.contentView layoutSubtreeIfNeeded];
            NSSize fitting = cal.fittingSize;
            NSEdgeInsets insets = window.contentView.additionalSafeAreaInsets;
            [window setContentSize:NSMakeSize(fitting.width + 4, fitting.height + insets.top + insets.bottom)];
            [window.contentView layoutSubtreeIfNeeded];
            CGFloat expectedWidth = 7 * SizePref.cellSize + 12 + (weeks.boolValue ? SizePref.cellSize - 2 : 0);
            Check(fabs(NSWidth(cal.frame) - expectedWidth) < 0.5, [NSString stringWithFormat:@"Original calendar width retained: actual %.2f expected %.2f", NSWidth(cal.frame), expectedWidth]);
            Check(NSMaxX(options.frame) <= NSWidth(cal.frame), @"Options fits inside calendar");
            Check(NSMaxX(pin.frame) <= NSMinX(options.frame), @"Header buttons do not overlap");
            MoCalGrid *grid = [cal valueForKey:@"dateGrid"];
            MoCalGrid *weekGrid = [cal valueForKey:@"weekGrid"];
            for (MoCalCell *cell in grid.cells) {
                [cell layoutSubtreeIfNeeded];
                Check(cell.lunarTextField.stringValue.length > 0, @"Every date has a lunar label");
                Check(NSMinY(cell.lunarTextField.frame) > 2 * SizePref.cellDotWidth + 2, @"Lunar label clears event dots");
                Check(NSMaxY(cell.lunarTextField.frame) <= NSMinY(cell.textField.frame) + 1.1, @"Date labels do not overlap");
                Check([grid cellAtPoint:NSMakePoint(NSMidX(cell.frame), NSMinY(cell.frame) + 2)] == cell, @"Lunar row hit testing");
            }
            Check(fabs(grid.rowHeight - weekGrid.rowHeight) < 0.01, @"Week and date rows align");
            NSRect highlightedCells = [window.contentView convertRect:grid.cellsRect fromView:grid];
            Check(fabs(NSMinY(highlightedCells) - 5) < 0.01, @"Only 5pt below highlight; bottom is not clipped");
            for (NSInteger month = 0; month < 12; month++) {
                cal.monthDate = MakeDate(2026, month, 1);
                MoCalCell *last = [grid cellWithDate:MakeDate(2026, month, DaysInMonth(2026, month))];
                NSRect lastRect = [cal convertRect:last.frame fromView:grid];
                Check(NSMinY(lastRect) >= 0.75, @"Full month-outline stroke fits in all 12 months");
            }
            [cal showTodayMonth:nil];
            [grid addRow];
            Check(grid.cells.lastObject.showsLunarDate, @"Added rows show lunar dates");
            [grid removeRow];
            [[cal valueForKey:@"btnNext"] performClick:nil];
            Check(cal.monthDate.month == 10, @"Next month");
            [[cal valueForKey:@"btnPrev"] performClick:nil];
            Check(cal.monthDate.month == 9, @"Previous month");
            [[cal valueForKey:@"btnToday"] performClick:nil];
            Check(CompareDates(cal.selectedDate, cal.todayDate) == 0, @"Return to today");
            [window.contentView layoutSubtreeIfNeeded];
            for (NSNumber *dark in @[@NO, @YES]) {
                cal.appearance = [NSAppearance appearanceNamed:dark.boolValue ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
                [cal setNeedsDisplay:YES];
                NSString *path = [snapshots stringByAppendingFormat:@"/calendar-%ld-weeks%@-%@.png", size, weeks, dark.boolValue ? @"dark" : @"light"];
                SaveSnapshot(cal, path);
                window.contentView.appearance = cal.appearance;
                [window.contentView displayIfNeeded];
                NSString *windowPath = [snapshots stringByAppendingFormat:@"/window-%ld-weeks%@-%@.png", size, weeks, dark.boolValue ? @"dark" : @"light"];
                SaveSnapshot(window.contentView, windowPath);
            }
            [cal setSelectedDate:MakeDate(2025, 6, 25)];
            [window.contentView layoutSubtreeIfNeeded];
            MoCalCell *leapCell = [grid cellWithDate:MakeDate(2025, 6, 25)];
            Check([leapCell.lunarTextField.stringValue isEqual:@"闰六月"], @"Leap month label in grid");
            NSSize leapTextSize = [leapCell.lunarTextField.stringValue sizeWithAttributes:@{NSFontAttributeName:leapCell.lunarTextField.font}];
            Check(leapTextSize.width <= NSWidth(leapCell.frame) - 2, @"Leap month label fits fixed column width");
            NSLog(@"PASS: size=%ld weeks=%@ %@", size, weeks, NSStringFromSize(fitting));
            [window orderOut:nil];
        }
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        TestLunar();
        if (argc >= 3) TestLayout(@(argv[1]), @(argv[2]));
    }
    return 0;
}
