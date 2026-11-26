#import <Cocoa/Cocoa.h>
#import "BirthdayNotifications.h"
@interface BirthdaysVC : NSViewController
- (instancetype)initWithStore:(BirthdayStore *)store notifications:(BirthdayNotifications *)notifications;
@property (nonatomic, copy) void (^sizeDidChange)(NSSize size);
- (void)showList;
@end
