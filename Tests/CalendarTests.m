#import <Cocoa/Cocoa.h>
#import "MoLunarDate.h"
#import "MoCalendar.h"
#import "MoCalGrid.h"
#import "MoCalCell.h"
#import "MoButton.h"
#import "Sizer.h"
#import "Themer.h"
#import "ItsycalWindow.h"
#import "BirthdaysVC.h"
#import "TooltipViewController.h"
#import "EventCenter.h"

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

@interface BirthdayCalendarDelegate : NSObject <MoCalendarDelegate> @end
@implementation BirthdayCalendarDelegate
- (void)calendarUpdated:(MoCalendar *)cal { [cal reloadData]; }
- (void)calendarSelectionChanged:(MoCalendar *)cal {}
- (NSArray *)dotColorsForDate:(MoDate)date useColor:(BOOL)useColor { return nil; }
- (BOOL)hasBirthdayOnDate:(MoDate)date { return date.year==2026 && date.month==9 && date.day==27; }
@end

@interface BirthdayTooltipFixture : NSObject <TooltipViewControllerDelegate>
@property (nonatomic) NSArray *people;
@property (nonatomic) NSArray *events;
@end
@implementation BirthdayTooltipFixture
- (NSArray *)birthdaysForDate:(MoDate)date { return self.people; }
- (NSArray *)eventsForDate:(MoDate)date { return self.events; }
@end

static void TestBirthdayTooltip(NSString *snapshots) {
    Birthday *a=[Birthday new]; a.name=@"妈妈";
    Birthday *b=[Birthday new]; b.name=@"小明";
    BirthdayTooltipFixture *fixture=[BirthdayTooltipFixture new]; fixture.people=@[a,b];
    TooltipViewController *tooltip=[TooltipViewController new]; tooltip.tooltipDelegate=fixture;
    Check([tooltip toolTipForDate:MakeDate(2026,9,27)],@"Birthday-only tooltip with no system calendar events");
    NSTextField *names=[tooltip valueForKey:@"birthdays"];
    Check([names.stringValue isEqual:@"🎂 妈妈\n🎂 小明"] && [names.textColor isEqual:NSColor.systemRedColor],@"All birthday names in red");
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,236,100) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.contentView=tooltip.view;
    [tooltip.view.widthAnchor constraintEqualToConstant:236].active=YES;
    [window setContentSize:tooltip.view.fittingSize]; [tooltip.view layoutSubtreeIfNeeded];
    Check(NSHeight(tooltip.view.frame)>20,@"Birthday tooltip has visible height");
    SaveSnapshot(tooltip.view,[snapshots stringByAppendingPathComponent:@"birthday-tooltip.png"]);
    fixture.people=@[];
    Check(![tooltip toolTipForDate:MakeDate(2026,9,28)],@"No empty tooltip on other dates");
    [window orderOut:nil];
}

static void TestBirthdayUI(NSString *snapshots) {
    NSURL *dir=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    BirthdayStore *store=[[BirthdayStore alloc] initWithURL:[dir URLByAppendingPathComponent:@"birthdays.json"]];
    BirthdaysVC *vc=[[BirthdaysVC alloc] initWithStore:store notifications:nil];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,340,300) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.contentViewController=vc;
    [window setContentSize:vc.view.fittingSize]; [vc.view layoutSubtreeIfNeeded];
    [vc performSelector:@selector(addBirthday:) withObject:nil];
    [window setContentSize:vc.view.fittingSize]; [vc.view layoutSubtreeIfNeeded];
    Check([[vc valueForKey:@"calendarType"] indexOfSelectedItem]==0,@"New birthday defaults to lunar");
    NSTextField *name=[vc valueForKey:@"nameField"]; name.stringValue=@"测试亲友";
    NSPopUpButton *month=[vc valueForKey:@"month"], *day=[vc valueForKey:@"day"];
    [month selectItemAtIndex:7]; [vc performSelector:@selector(monthChanged:) withObject:nil]; [day selectItemAtIndex:14];
    SaveSnapshot(vc.view,[snapshots stringByAppendingPathComponent:@"birthday-editor.png"]);
    [vc performSelector:@selector(save:) withObject:nil];
    Check(store.birthdays.count==1 && store.birthdays.firstObject.month==8 && store.birthdays.firstObject.day==15,@"Save editor values");
    [window setContentSize:vc.view.fittingSize]; [vc.view layoutSubtreeIfNeeded];
    SaveSnapshot(vc.view,[snapshots stringByAppendingPathComponent:@"birthday-list.png"]);
    [vc performSelector:@selector(showEditor:) withObject:store.birthdays.firstObject];
    NSPopUpButton *type=[vc valueForKey:@"calendarType"]; [type selectItemAtIndex:1];
    [vc performSelector:@selector(calendarChanged:) withObject:nil];
    month=[vc valueForKey:@"month"]; day=[vc valueForKey:@"day"];
    [month selectItemAtIndex:1]; [vc performSelector:@selector(monthChanged:) withObject:nil];
    Check(day.numberOfItems==29,@"Gregorian February allows leap-day birthday");
    [day selectItemAtIndex:28]; [vc performSelector:@selector(save:) withObject:nil];
    Check(store.birthdays.count==1 && !store.birthdays.firstObject.lunar && !store.birthdays.firstObject.leapMonth && store.birthdays.firstObject.day==29,@"Edit birthday from lunar to Gregorian without adding another record");
    [window orderOut:nil];
    [NSFileManager.defaultManager removeItemAtURL:dir error:nil];
    NSLog(@"PASS: birthday list, editor, defaults and saved values");
}

static void TestLayout(NSString *sourceRoot, NSString *snapshots) {
    [NSApplication sharedApplication];
    [Sizer shared];
    [Themer shared];
    LoadImages(sourceRoot);
    BirthdayCalendarDelegate *birthdayDelegate=[BirthdayCalendarDelegate new];
    for (NSInteger size = 0; size <= 2; size++) {
        SizePref.sizePreference = size;
        for (NSNumber *weeks in @[@NO, @YES]) {
            MoCalendar *cal = [MoCalendar new];
            MoButton *pin = [MoButton new];
            pin.image = [NSImage imageNamed:@"btnPin"];
            MoButton *options = [MoButton new];
            options.image = [NSImage imageNamed:@"btnOpt"];
            MoButton *birthday=[MoButton new]; birthday.image=[NSImage imageWithSystemSymbolName:@"birthday.cake" accessibilityDescription:@"亲友生日"];
            [cal installBirthdayButton:birthday pinButton:pin optionsButton:options];
            cal.delegate=birthdayDelegate;
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
            Check(NSMaxX(birthday.frame) <= NSMinX([[cal valueForKey:@"btnPrev"] frame]),@"Birthday button before previous month");
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
            MoCalCell *birthdayCell=[grid cellWithDate:MakeDate(2026,9,27)];
            Check(birthdayCell.hasBirthday && [birthdayCell.textField.textColor isEqual:NSColor.systemRedColor],@"Birthday remains red with event dots disabled");
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
    TestBirthdayUI(snapshots);
    TestBirthdayTooltip(snapshots);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        TestLunar();
        if (argc >= 3) TestLayout(@(argv[1]), @(argv[2]));
    }
    return 0;
}
