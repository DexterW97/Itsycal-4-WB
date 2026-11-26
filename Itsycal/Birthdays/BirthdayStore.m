#import "BirthdayStore.h"

NSNotificationName const BirthdayStoreDidChangeNotification = @"BirthdayStoreDidChange";
static NSError *BirthdayError(NSString *message) {
    return [NSError errorWithDomain:@"Itsycal.Birthdays" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}
@implementation Birthday
- (instancetype)init {
    if ((self = [super init])) { _identifier = NSUUID.UUID.UUIDString; _name = @""; _lunar = YES; _month = 1; _day = 1; }
    return self;
}
- (BOOL)isValid {
    if (!self.identifier.length || ![self.name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length || self.name.length > 80) return NO;
    if (self.month < 1 || self.month > 12 || self.day < 1) return NO;
    return self.lunar ? self.day <= 30 : (!self.leapMonth && self.day <= DaysInMonth(2024, self.month - 1));
}
- (NSString *)dateDescription {
    if (!self.lunar) return [NSString stringWithFormat:@"阳历 %zd月%zd日", self.month, self.day];
    NSArray *months = @[@"正月",@"二月",@"三月",@"四月",@"五月",@"六月",@"七月",@"八月",@"九月",@"十月",@"冬月",@"腊月"];
    NSArray *days = @[@"初一",@"初二",@"初三",@"初四",@"初五",@"初六",@"初七",@"初八",@"初九",@"初十",@"十一",@"十二",@"十三",@"十四",@"十五",@"十六",@"十七",@"十八",@"十九",@"二十",@"廿一",@"廿二",@"廿三",@"廿四",@"廿五",@"廿六",@"廿七",@"廿八",@"廿九",@"三十"];
    if (![self isValid]) return @"无效生日";
    return [NSString stringWithFormat:@"阴历 %@%@%@", self.leapMonth ? @"闰" : @"", months[self.month-1], days[self.day-1]];
}
- (NSDictionary *)dictionary {
    return @{@"id":self.identifier, @"name":self.name, @"lunar":@(self.lunar), @"leapMonth":@(self.leapMonth), @"month":@(self.month), @"day":@(self.day)};
}
+ (instancetype)fromDictionary:(NSDictionary *)d {
    if (![d isKindOfClass:NSDictionary.class] || ![d[@"id"] isKindOfClass:NSString.class] || ![d[@"name"] isKindOfClass:NSString.class]) return nil;
    for (NSString *key in @[@"lunar",@"leapMonth",@"month",@"day"]) if (![d[key] isKindOfClass:NSNumber.class]) return nil;
    Birthday *b = [Birthday new]; b.identifier=d[@"id"]; b.name=d[@"name"]; b.lunar=[d[@"lunar"] boolValue]; b.leapMonth=[d[@"leapMonth"] boolValue]; b.month=[d[@"month"] integerValue]; b.day=[d[@"day"] integerValue];
    return [b isValid] ? b : nil;
}
@end

static NSCalendar *CivilCalendar(NSString *identifier) {
    NSMutableDictionary *thread = NSThread.currentThread.threadDictionary;
    NSString *key = [@"BirthdayCalendar." stringByAppendingString:identifier];
    NSCalendar *cal = thread[key];
    if (!cal) { cal = [[NSCalendar alloc] initWithCalendarIdentifier:identifier]; cal.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"]; thread[key]=cal; }
    return cal;
}
static BOOL HasLeapMonth(NSCalendar *lunar, NSDate *date, NSInteger month) {
    NSDate *start; NSTimeInterval duration;
    if (![lunar rangeOfUnit:NSCalendarUnitYear startDate:&start interval:&duration forDate:date]) return NO;
    NSDate *end = [start dateByAddingTimeInterval:duration];
    for (NSDate *d = start; [d compare:end] == NSOrderedAscending; d = [lunar dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:d options:0]) {
        NSDateComponents *p = [lunar components:NSCalendarUnitMonth fromDate:d];
        if (p.month == month && p.isLeapMonth) return YES;
    }
    return NO;
}
BOOL BirthdayMatchesDate(Birthday *b, MoDate date) {
    if (![b isValid] || !IsValidDate(date)) return NO;
    if (!b.lunar) return date.month + 1 == b.month && date.day == MIN(b.day, DaysInMonth(date.year, date.month));
    NSCalendar *solar = CivilCalendar(NSCalendarIdentifierGregorian), *lunar = CivilCalendar(NSCalendarIdentifierChinese);
    NSDateComponents *civil = [NSDateComponents new]; civil.year=date.year; civil.month=date.month+1; civil.day=date.day; civil.hour=12;
    NSDate *instant = [solar dateFromComponents:civil];
    NSDateComponents *parts = [lunar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:instant];
    if (parts.month != b.month) return NO;
    if (!b.leapMonth && parts.isLeapMonth) return NO;
    if (b.leapMonth && !parts.isLeapMonth && HasLeapMonth(lunar, instant, b.month)) return NO;
    NSInteger length = [lunar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:instant].length;
    return parts.day == MIN(b.day, length);
}
MoDate BirthdayNextDate(Birthday *b, MoDate start) {
    for (NSInteger i=0; i<400; i++) { MoDate d=AddDaysToDate(i,start); if (BirthdayMatchesDate(b,d)) return d; }
    return (MoDate){0,0,0,NO_JULIAN};
}
NSArray<NSDictionary *> *BirthdayReminderPlan(NSArray<Birthday *> *birthdays, NSDate *now, NSCalendar *calendar) {
    NSMutableArray *plan = [NSMutableArray new];
    NSDate *start = [calendar startOfDayForDate:now];
    for (NSInteger i=0; i<60; i++) {
        NSDate *day = [calendar dateByAddingUnit:NSCalendarUnitDay value:i toDate:start options:0];
        NSDate *fire = [calendar dateBySettingHour:9 minute:0 second:0 ofDate:day options:0];
        if ([fire compare:now] != NSOrderedDescending) continue;
        MoDate civil = MakeDateWithNSDate(day, calendar);
        NSMutableArray *lines = [NSMutableArray new];
        for (NSInteger offset=0; offset<=3; offset++) {
            MoDate target = AddDaysToDate(offset,civil);
            for (Birthday *b in birthdays) if (BirthdayMatchesDate(b,target)) {
                NSString *when = offset == 0 ? @"今天生日" : [NSString stringWithFormat:@"%zd天后生日", offset];
                [lines addObject:[NSString stringWithFormat:@"🎂 %@ · %@（%@）", b.name, when, b.dateDescription]];
            }
        }
        if (lines.count) [plan addObject:@{@"id":[NSString stringWithFormat:@"birthday.%04zd-%02zd-%02zd",civil.year,civil.month+1,civil.day], @"fireDate":fire, @"body":[lines componentsJoinedByString:@"\n"]}];
    }
    return plan;
}

@implementation BirthdayStore {
    NSArray<Birthday *> *_birthdays;
    BOOL _notificationsEnabled;
}
+ (instancetype)shared {
    static BirthdayStore *store; static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *support = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
        store = [[self alloc] initWithURL:[support URLByAppendingPathComponent:@"Itsycal-4-WB/birthdays.json"]];
    }); return store;
}
- (instancetype)initWithURL:(NSURL *)url {
    if ((self=[super init])) {
        _fileURL=url; _birthdays=@[]; _notificationsEnabled=YES;
        if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
            NSError *error; NSData *data=[NSData dataWithContentsOfURL:url options:0 error:&error];
            id root=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
            if (![root isKindOfClass:NSDictionary.class] || ![root[@"version"] isEqual:@1] || ![root[@"birthdays"] isKindOfClass:NSArray.class] || ![root[@"notificationsEnabled"] isKindOfClass:NSNumber.class]) { _loadError=error ?: BirthdayError(@"生日文件格式无效，请备份并修复后重新打开应用；原文件不会被覆盖。"); return self; }
            NSMutableArray *entries=[NSMutableArray new]; NSMutableSet *ids=[NSMutableSet new];
            for (id d in root[@"birthdays"]) { Birthday *b=[Birthday fromDictionary:d]; if (!b || [ids containsObject:b.identifier]) { _loadError=BirthdayError(@"生日文件包含无效或重复记录，原文件不会被覆盖。"); return self; } [entries addObject:b]; [ids addObject:b.identifier]; }
            _birthdays=[entries copy]; _notificationsEnabled=[root[@"notificationsEnabled"] boolValue];
        }
    } return self;
}
- (NSArray *)birthdays { NSMutableArray *result=[NSMutableArray new]; for (Birthday *b in _birthdays) [result addObject:[Birthday fromDictionary:b.dictionary]]; return result; }
- (BOOL)notificationsEnabled { return _notificationsEnabled; }
- (BOOL)writeEntries:(NSArray *)entries enabled:(BOOL)enabled error:(NSError **)error {
    if (self.loadError) { if (error) *error=self.loadError; return NO; }
    NSMutableArray *rows=[NSMutableArray new]; for (Birthday *b in entries) [rows addObject:b.dictionary];
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"version":@1,@"notificationsEnabled":@(enabled),@"birthdays":rows} options:NSJSONWritingPrettyPrinted error:error];
    NSFileManager *fm=NSFileManager.defaultManager;
    if (!data || ![fm createDirectoryAtURL:[self.fileURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error]) return NO;
    if (![data writeToURL:self.fileURL options:NSDataWritingAtomic error:error]) return NO;
    [fm setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:self.fileURL.path error:nil];
    _birthdays=[entries copy]; _notificationsEnabled=enabled;
    [[NSNotificationCenter defaultCenter] postNotificationName:BirthdayStoreDidChangeNotification object:self]; return YES;
}
- (BOOL)saveBirthday:(Birthday *)birthday error:(NSError **)error {
    if (![birthday isValid]) { if (error) *error=BirthdayError(@"请填写姓名并选择有效的生日。姓名最多80个字符。"); return NO; }
    NSMutableArray *rows=[self.birthdays mutableCopy]; NSUInteger index=[rows indexOfObjectPassingTest:^BOOL(Birthday *b, NSUInteger idx, BOOL *stop) { return [b.identifier isEqual:birthday.identifier]; }];
    Birthday *copy=[Birthday fromDictionary:birthday.dictionary];
    if (index==NSNotFound) [rows addObject:copy]; else rows[index]=copy;
    return [self writeEntries:rows enabled:_notificationsEnabled error:error];
}
- (BOOL)deleteBirthday:(NSString *)identifier error:(NSError **)error {
    NSMutableArray *rows=[self.birthdays mutableCopy]; NSIndexSet *indices=[rows indexesOfObjectsPassingTest:^BOOL(Birthday *b, NSUInteger idx, BOOL *stop){return [b.identifier isEqual:identifier];}]; [rows removeObjectsAtIndexes:indices];
    return [self writeEntries:rows enabled:_notificationsEnabled error:error];
}
- (BOOL)setNotificationsEnabled:(BOOL)enabled error:(NSError **)error { return [self writeEntries:self.birthdays enabled:enabled error:error]; }
- (NSArray *)birthdaysOnDate:(MoDate)date { NSMutableArray *rows=[NSMutableArray new]; for (Birthday *b in _birthdays) if (BirthdayMatchesDate(b,date)) [rows addObject:[Birthday fromDictionary:b.dictionary]]; return rows; }
@end
