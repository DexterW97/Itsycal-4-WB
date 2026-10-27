#import "MoLunarDate.h"

NSString *MoLunarDateLabel(MoDate date)
{
    if (!IsValidDate(date)) return @"";

    // Thread-local calendars avoid sharing mutable Foundation objects. This also
    // avoids constructing two calendars for each cell when changing months.
    NSMutableDictionary *thread = NSThread.currentThread.threadDictionary;
    NSCalendar *solar = thread[@"MoLunarSolarCalendar"];
    NSCalendar *lunar = thread[@"MoLunarChineseCalendar"];
    if (!solar || !lunar) {
        NSTimeZone *zone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
        solar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        lunar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierChinese];
        solar.timeZone = zone;
        lunar.timeZone = zone;
        thread[@"MoLunarSolarCalendar"] = solar;
        thread[@"MoLunarChineseCalendar"] = lunar;
    }
    NSDateComponents *civil = [NSDateComponents new];
    civil.year = date.year;
    civil.month = date.month + 1;
    civil.day = date.day;
    civil.hour = 12;
    NSDate *instant = [solar dateFromComponents:civil];
    if (!instant) return @"";
    NSDateComponents *parts = [lunar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:instant];
    NSInteger day = parts.day;
    NSInteger month = parts.month;
    if (day < 1 || day > 30 || month < 1 || month > 12) return @"";

    // Traditional festivals do not recur in a leap month.
    if (!parts.isLeapMonth) {
        if (month == 1 && day == 1) return @"春节";
        if (month == 1 && day == 15) return @"元宵";
        if (month == 5 && day == 5) return @"端午";
        if (month == 7 && day == 7) return @"七夕";
        if (month == 7 && day == 15) return @"中元";
        if (month == 8 && day == 15) return @"中秋";
        if (month == 9 && day == 9) return @"重阳";
        if (month == 12 && day == 8) return @"腊八";
    }
    if (month == 12 && day >= 29) {
        NSDate *tomorrow = [solar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:instant options:0];
        NSDateComponents *next = [lunar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:tomorrow];
        if (next.month == 1 && next.day == 1 && !next.isLeapMonth) return @"除夕";
    }
    if (day == 1) {
        NSArray *months = @[@"正月", @"二月", @"三月", @"四月", @"五月", @"六月",
                            @"七月", @"八月", @"九月", @"十月", @"冬月", @"腊月"];
        return [NSString stringWithFormat:@"%@%@", parts.isLeapMonth ? @"闰" : @"", months[month - 1]];
    }
    NSArray *days = @[@"初一", @"初二", @"初三", @"初四", @"初五", @"初六", @"初七", @"初八", @"初九", @"初十",
                     @"十一", @"十二", @"十三", @"十四", @"十五", @"十六", @"十七", @"十八", @"十九", @"二十",
                     @"廿一", @"廿二", @"廿三", @"廿四", @"廿五", @"廿六", @"廿七", @"廿八", @"廿九", @"三十"];
    return days[day - 1];
}
