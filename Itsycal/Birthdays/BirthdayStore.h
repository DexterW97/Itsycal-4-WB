#import <Foundation/Foundation.h>
#import "MoDate.h"

extern NSNotificationName const BirthdayStoreDidChangeNotification;

@interface Birthday : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) BOOL lunar;
@property (nonatomic) BOOL leapMonth;
@property (nonatomic) NSInteger month;
@property (nonatomic) NSInteger day;
- (BOOL)isValid;
- (NSString *)dateDescription;
- (NSDictionary *)dictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;
@end

// Civil-date calculations are independent of the Mac's current time zone.
BOOL BirthdayMatchesDate(Birthday *birthday, MoDate date);
MoDate BirthdayNextDate(Birthday *birthday, MoDate start);
// One combined reminder per day, at 09:00 in the supplied local calendar.
NSArray<NSDictionary *> *BirthdayReminderPlan(NSArray<Birthday *> *birthdays, NSDate *now, NSCalendar *calendar);

@interface BirthdayStore : NSObject
@property (nonatomic, readonly) NSArray<Birthday *> *birthdays;
@property (nonatomic, readonly) NSError *loadError;
@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) BOOL notificationsEnabled;
+ (instancetype)shared;
- (instancetype)initWithURL:(NSURL *)url;
- (BOOL)saveBirthday:(Birthday *)birthday error:(NSError **)error;
- (BOOL)deleteBirthday:(NSString *)identifier error:(NSError **)error;
- (BOOL)setNotificationsEnabled:(BOOL)enabled error:(NSError **)error;
- (NSArray<Birthday *> *)birthdaysOnDate:(MoDate)date;
@end
