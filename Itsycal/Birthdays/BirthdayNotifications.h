#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>
#import "BirthdayStore.h"
extern NSNotificationName const BirthdayNotificationStatusChanged;
@interface BirthdayNotifications : NSObject <UNUserNotificationCenterDelegate>
@property (nonatomic, readonly) NSString *status;
@property (nonatomic, copy) void (^openBirthdays)(void);
- (instancetype)initWithStore:(BirthdayStore *)store;
- (void)refresh;
- (void)requestPermission;
- (void)openSystemSettings;
@end
