#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "BirthdayStore.h"
static void Expect(BOOL condition, NSString *message) { if (!condition) { NSLog(@"FAIL: %@", message); exit(1); } }
static Birthday *Person(NSString *name, BOOL lunar, NSInteger month, NSInteger day) {
    Birthday *b=[Birthday new]; b.name=name; b.lunar=lunar; b.month=month; b.day=day; return b;
}
static NSDate *Instant(NSCalendar *calendar, NSInteger year, NSInteger month, NSInteger day, NSInteger hour) {
    NSDateComponents *c=[NSDateComponents new]; c.year=year; c.month=month; c.day=day; c.hour=hour; return [calendar dateFromComponents:c];
}
int main(void) { @autoreleasepool {
    Birthday *solar=Person(@"阳历",NO,2,29);
    Expect(BirthdayMatchesDate(solar,MakeDate(2025,1,28)),@"Feb29 falls back in a common year");
    Expect(!BirthdayMatchesDate(solar,MakeDate(2024,1,28)),@"Leap year has no premature birthday");
    Expect(BirthdayMatchesDate(solar,MakeDate(2024,1,29)),@"Leap year birthday");
    Birthday *lunar=Person(@"阴历",YES,1,1);
    Expect(BirthdayMatchesDate(lunar,MakeDate(2026,1,17)),@"Known lunar New Year");
    lunar.leapMonth=YES;
    Expect(BirthdayMatchesDate(lunar,MakeDate(2026,1,17)),@"Leap-month birthday falls back to regular month");
    lunar.month=6;
    Expect(BirthdayMatchesDate(lunar,MakeDate(2025,6,25)),@"Leap sixth month begins July25");
    Expect(!BirthdayMatchesDate(lunar,MakeDate(2025,5,25)),@"Leap birthday excludes normal same month");
    lunar.leapMonth=NO;
    Expect(!BirthdayMatchesDate(lunar,MakeDate(2025,6,25)),@"Normal birthday excludes leap month");
    Expect(BirthdayMatchesDate(lunar,MakeDate(2025,5,25)),@"Normal sixth month begins June25");
    lunar.month=12; lunar.day=30;
    Expect(BirthdayMatchesDate(lunar,MakeDate(2022,0,31)),@"Lunar30 falls back to29 in a small month");
    Expect(!BirthdayMatchesDate(lunar,MakeDate(2022,1,1)),@"No birthday on next lunar month");
    Expect(!BirthdayMatchesDate(Person(@"",YES,1,1),MakeDate(2026,1,17)),@"Reject empty names");
    Expect(![Person(@"无效",NO,4,31) isValid],@"Reject impossible Gregorian dates");
    NSCalendar *calendar=[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]; calendar.timeZone=[NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    Birthday *newYear=Person(@"小明",NO,1,1);
    NSArray *plan=BirthdayReminderPlan(@[newYear],Instant(calendar,2026,12,28,8),calendar);
    Expect(plan.count==4,@"Four reminders from three days before through birthday");
    for (NSInteger i=0;i<4;i++) {
        NSDateComponents *c=[calendar components:NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour fromDate:plan[i][@"fireDate"]];
        Expect(c.hour==9,@"Every reminder at09 local");
        Expect(c.month==(i<3?12:1) && c.day==(i<3?29+i:1),@"Correct cross-year reminder dates");
    }
    NSArray *sameDay=BirthdayReminderPlan(@[newYear,Person(@"妈妈",NO,1,1)],Instant(calendar,2026,12,29,8),calendar);
    Expect(sameDay.count==4 && [sameDay.firstObject[@"body"] containsString:@"小明"] && [sameDay.firstObject[@"body"] containsString:@"妈妈"],@"Merge multiple people into one notification per date");
    Expect(BirthdayReminderPlan(@[newYear],Instant(calendar,2026,12,29,10),calendar).count==3,@"Do not resend past09 reminder");
    Expect(BirthdayReminderPlan(@[],NSDate.date,calendar).count==0,@"Empty records have no reminders");
    // Same civil birthday, different local UTC offsets: still09:00 in that location.
    calendar.timeZone=[NSTimeZone timeZoneWithName:@"America/Los_Angeles"];
    plan=BirthdayReminderPlan(@[newYear],Instant(calendar,2026,12,29,8),calendar);
    Expect([calendar component:NSCalendarUnitHour fromDate:plan.firstObject[@"fireDate"]]==9,@"09:00 in another timezone");
    Birthday *spring=Person(@"春节",YES,1,1);
    plan=BirthdayReminderPlan(@[spring],Instant(calendar,2026,2,13,8),calendar);
    Expect(plan.count==4 && [plan.lastObject[@"body"] containsString:@"今天生日"],@"Lunar birthday notification period");
    NSMutableArray *many=[NSMutableArray new]; for (NSInteger m=1;m<=12;m++) for (NSInteger d=1;d<=28;d++) [many addObject:Person(@"亲友",NO,m,d)];
    Expect(BirthdayReminderPlan(many,Instant(calendar,2026,3,1,8),calendar).count<=60,@"Bound pending notifications regardless of number of records");
    NSURL *dir=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    NSURL *url=[dir URLByAppendingPathComponent:@"birthdays.json"];
    BirthdayStore *store=[[BirthdayStore alloc] initWithURL:url]; NSError *error;
    Expect([store saveBirthday:newYear error:&error],@"Save birthday");
    BirthdayStore *loaded=[[BirthdayStore alloc] initWithURL:url];
    Expect(loaded.birthdays.count==1 && [loaded.birthdays.firstObject.name isEqual:@"小明"],@"Persistence after restart");
    newYear.name=@"小明改名"; Expect([loaded saveBirthday:newYear error:&error] && loaded.birthdays.count==1,@"Edit by id without duplicates");
    Expect([loaded setNotificationsEnabled:NO error:&error],@"Disable notifications");
    Expect(![[[BirthdayStore alloc] initWithURL:url] notificationsEnabled],@"Remember notification setting");
    Expect([loaded deleteBirthday:newYear.identifier error:&error] && loaded.birthdays.count==0,@"Delete birthday");
    [@"broken" writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
    BirthdayStore *broken=[[BirthdayStore alloc] initWithURL:url];
    Expect(broken.loadError!=nil && ![broken saveBirthday:newYear error:&error],@"Do not overwrite damaged data");
    Expect([[NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil] isEqual:@"broken"],@"Preserve unreadable original");
    [[NSFileManager defaultManager] removeItemAtURL:dir error:nil];
    NSLog(@"PASS: birthday recurrence, leap rules, notification dates09:00, grouping, persistence, editing, deletion and damaged-file protection");
} return 0; }
