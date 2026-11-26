#import "BirthdayNotifications.h"
NSNotificationName const BirthdayNotificationStatusChanged = @"BirthdayNotificationStatusChanged";
@implementation BirthdayNotifications {
    BirthdayStore *_store;
    UNUserNotificationCenter *_center;
    NSUInteger _generation;
}
- (instancetype)initWithStore:(BirthdayStore *)store {
    if ((self=[super init])) { _store=store; _center=UNUserNotificationCenter.currentNotificationCenter; _center.delegate=self; _status=@"通知将在每天上午9:00发送"; }
    return self;
}
- (void)setStatusText:(NSString *)text {
    _status=[text copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:BirthdayNotificationStatusChanged object:self];
}
- (void)requestPermission {
    [_center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (settings.authorizationStatus == UNAuthorizationStatusDenied) { [self refresh]; return; }
            [self->_center requestAuthorizationWithOptions:UNAuthorizationOptionAlert|UNAuthorizationOptionSound completionHandler:^(BOOL granted, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{ if (error) [self setStatusText:error.localizedDescription]; else [self refresh]; });
            }];
        });
    }];
}
- (void)openSystemSettings {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.Notifications-Settings.extension"]];
}
- (void)refresh {
    NSAssert(NSThread.isMainThread, @"Notification scheduling must run on the main thread");
    NSUInteger generation=++_generation;
    // Never replace schedules from an unreadable store with an empty list.
    if (_store.loadError) { [self setStatusText:@"生日文件无法读取，请先修复文件"]; return; }
    [_center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self->_generation) return;
            BOOL authorized=settings.authorizationStatus==UNAuthorizationStatusAuthorized || settings.authorizationStatus==UNAuthorizationStatusProvisional;
            BOOL enabled=self->_store.notificationsEnabled;
            NSArray *plan=enabled && authorized ? BirthdayReminderPlan(self->_store.birthdays, NSDate.date, [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]) : @[];
            [self->_center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (generation != self->_generation) return;
                    NSMutableArray *old=[NSMutableArray new]; for (UNNotificationRequest *r in requests) if ([r.identifier hasPrefix:@"birthday."]) [old addObject:r.identifier];
                    [self->_center removePendingNotificationRequestsWithIdentifiers:old];
                    if (!enabled) { [self setStatusText:@"生日通知已关闭"]; return; }
                    if (!authorized) { [self setStatusText:@"请允许通知，并在系统设置中开启横幅与声音"]; return; }
                    [self setStatusText:[NSString stringWithFormat:@"每天9:00 · 已安排未来60天内的%lu条提醒",(unsigned long)plan.count]];
                    for (NSDictionary *entry in plan) {
                        UNMutableNotificationContent *content=[UNMutableNotificationContent new]; content.title=@"🎂 生日提醒"; content.body=entry[@"body"]; content.sound=UNNotificationSound.defaultSound;
                        // Components use the local zone at scheduling time; timezone changes rebuild the plan.
                        NSCalendar *calendar=[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
                        NSDateComponents *parts=[calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute fromDate:entry[@"fireDate"]];
                        parts.calendar=calendar;
                        parts.timeZone=calendar.timeZone;
                        UNCalendarNotificationTrigger *trigger=[UNCalendarNotificationTrigger triggerWithDateMatchingComponents:parts repeats:NO];
                        UNNotificationRequest *request=[UNNotificationRequest requestWithIdentifier:entry[@"id"] content:content trigger:trigger];
                        __weak typeof(self) weakSelf=self;
                        [self->_center addNotificationRequest:request withCompletionHandler:^(NSError *error) {
                            if (error) dispatch_async(dispatch_get_main_queue(), ^{ __strong typeof(weakSelf) strongSelf=weakSelf; if (strongSelf && generation==strongSelf->_generation) [strongSelf setStatusText:[@"通知安排失败：" stringByAppendingString:error.localizedDescription]]; });
                        }];
                    }
                });
            }];
        });
    }];
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner|UNNotificationPresentationOptionList|UNNotificationPresentationOptionSound);
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    dispatch_async(dispatch_get_main_queue(), ^{ if (self.openBirthdays) self.openBirthdays(); completionHandler(); });
}
@end
