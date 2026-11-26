#import "BirthdaysVC.h"
#import "MoThemeView.h"

@implementation BirthdaysVC {
    BirthdayStore *_store;
    BirthdayNotifications *_notifications;
    NSStackView *_stack;
    NSTextField *_nameField, *_statusLabel;
    NSPopUpButton *_calendarType, *_month, *_day;
    NSButton *_leap, *_notify;
    Birthday *_editing;
}
- (instancetype)initWithStore:(BirthdayStore *)store notifications:(BirthdayNotifications *)notifications {
    if ((self=[super initWithNibName:nil bundle:nil])) {
        _store=store; _notifications=notifications;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusChanged:) name:BirthdayNotificationStatusChanged object:notifications];
    } return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)loadView { [self showList]; }
- (void)statusChanged:(NSNotification *)note { _statusLabel.stringValue=_notifications.status ?: @""; }
- (NSTextField *)label:(NSString *)text small:(BOOL)small {
    NSTextField *label=[NSTextField wrappingLabelWithString:text];
    label.font=[NSFont systemFontOfSize:small ? 11 : 13];
    if (small) label.textColor=NSColor.secondaryLabelColor;
    return label;
}
- (NSButton *)button:(NSString *)title action:(SEL)action {
    return [NSButton buttonWithTitle:title target:self action:action];
}
- (NSStackView *)row:(NSArray<NSView *> *)views {
    NSStackView *row=[NSStackView stackViewWithViews:views]; row.orientation=NSUserInterfaceLayoutOrientationHorizontal; row.spacing=6; row.alignment=NSLayoutAttributeCenterY; return row;
}
- (void)beginPage:(NSString *)title {
    NSView *root=self.isViewLoaded ? self.view : [MoThemeView new];
    root.subviews=@[];
    _statusLabel=nil;
    _stack=[NSStackView new]; _stack.orientation=NSUserInterfaceLayoutOrientationVertical; _stack.alignment=NSLayoutAttributeLeading; _stack.spacing=10; _stack.translatesAutoresizingMaskIntoConstraints=NO;
    [root addSubview:_stack];
    if (!self.isViewLoaded) [root.widthAnchor constraintEqualToConstant:340].active=YES;
    [NSLayoutConstraint activateConstraints:@[
        [_stack.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:16],
        [_stack.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-16],
        [_stack.topAnchor constraintEqualToAnchor:root.topAnchor constant:14],
        [_stack.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-14],
    ]];
    NSTextField *heading=[self label:title small:NO]; heading.font=[NSFont boldSystemFontOfSize:15]; [_stack addArrangedSubview:heading]; self.view=root;
}
- (void)finishPage {
    [self.view layoutSubtreeIfNeeded];
    self.preferredContentSize=self.view.fittingSize;
    if (self.sizeDidChange) self.sizeDidChange(self.preferredContentSize);
}
- (void)showError:(NSError *)error {
    NSAlert *alert=[NSAlert new]; alert.messageText=@"无法保存生日"; alert.informativeText=error.localizedDescription; [alert runModal];
}
- (void)showList {
    _editing=nil; [self beginPage:@"🎂 亲友生日"];
    if (_store.loadError) [_stack addArrangedSubview:[self label:_store.loadError.localizedDescription small:YES]];
    NSArray<Birthday *> *birthdays=_store.birthdays;
    NSCalendar *solar=[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]; MoDate today=MakeDateWithNSDate(NSDate.date,solar);
    NSMutableArray *entries=[NSMutableArray new];
    for (Birthday *birthday in birthdays) [entries addObject:@{@"birthday":birthday,@"next":@(BirthdayNextDate(birthday,today).julian)}];
    [entries sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b){return [a[@"next"] compare:b[@"next"]];}];
    if (entries.count) {
        NSStackView *list=[NSStackView new]; list.orientation=NSUserInterfaceLayoutOrientationVertical; list.alignment=NSLayoutAttributeLeading; list.spacing=10;
        for (NSDictionary *entry in entries) {
            Birthday *birthday=entry[@"birthday"]; MoDate next=MakeGregorian([entry[@"next"] integerValue]);
            NSTextField *description=[self label:[NSString stringWithFormat:@"%@\n%@ · 下次 %zd/%zd/%zd",birthday.name,birthday.dateDescription,next.year,next.month+1,next.day] small:NO];
            [description.widthAnchor constraintEqualToConstant:182].active=YES;
            NSButton *edit=[self button:@"编辑" action:@selector(editBirthday:)]; edit.identifier=birthday.identifier; edit.accessibilityLabel=[@"编辑生日：" stringByAppendingString:birthday.name];
            NSButton *remove=[self button:@"删除" action:@selector(removeBirthday:)]; remove.identifier=birthday.identifier; remove.accessibilityLabel=[@"删除生日：" stringByAppendingString:birthday.name];
            [list addArrangedSubview:[self row:@[description,edit,remove]]];
        }
        NSScrollView *scroll=[NSScrollView new]; scroll.hasVerticalScroller=YES; scroll.drawsBackground=NO; scroll.documentView=list; list.translatesAutoresizingMaskIntoConstraints=NO;
        [NSLayoutConstraint activateConstraints:@[
            [scroll.widthAnchor constraintEqualToConstant:308], [scroll.heightAnchor constraintEqualToConstant:MIN(240,entries.count*54)],
            [list.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor], [list.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
            [list.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        ]]; [_stack addArrangedSubview:scroll];
    } else if (!_store.loadError) [_stack addArrangedSubview:[self label:@"还没有记录生日，点击下方新增。" small:YES]];
    NSButton *add=[self button:@"＋ 新增生日" action:@selector(addBirthday:)]; add.enabled=!_store.loadError; [_stack addArrangedSubview:add];
    _notify=[NSButton checkboxWithTitle:@"生日通知（提前3天至当天，每早9:00）" target:self action:@selector(toggleNotifications:)]; _notify.state=_store.notificationsEnabled ? NSControlStateValueOn : NSControlStateValueOff; _notify.enabled=!_store.loadError; [_stack addArrangedSubview:_notify];
    _statusLabel=[self label:_notifications.status ?: @"通知按本地时区发送" small:YES]; [_stack addArrangedSubview:_statusLabel];
    [_stack addArrangedSubview:[self row:@[[self button:@"允许通知" action:@selector(allowNotifications:)],[self button:@"系统通知设置" action:@selector(openSettings:)]]]];
    [_stack addArrangedSubview:[self label:@"请在设置中开启“登录时启动”，以持续更新提醒。" small:YES]];
    [self finishPage];
}
- (void)addBirthday:(id)sender { [self showEditor:[Birthday new]]; }
- (void)editBirthday:(NSButton *)sender { for (Birthday *b in _store.birthdays) if ([b.identifier isEqual:sender.identifier]) { [self showEditor:b]; return; } }
- (void)showEditor:(Birthday *)birthday {
    _editing=[Birthday fromDictionary:birthday.dictionary];
    // A new entry has an empty name until the user fills it in.
    if (!_editing) { _editing=[Birthday new]; _editing.identifier=birthday.identifier; }
    [self beginPage:birthday.name.length ? @"编辑生日" : @"新增生日"];
    _calendarType=[NSPopUpButton new]; [_calendarType addItemsWithTitles:@[@"阴历（农历）",@"阳历（公历）"]]; [_calendarType selectItemAtIndex:birthday.lunar ? 0 : 1]; _calendarType.target=self; _calendarType.action=@selector(calendarChanged:); _calendarType.accessibilityLabel=@"生日历法";
    [_stack addArrangedSubview:[self row:@[[self label:@"历法" small:NO],_calendarType]]];
    _nameField=[NSTextField textFieldWithString:birthday.name]; _nameField.placeholderString=@"亲友姓名"; _nameField.accessibilityLabel=@"姓名"; [_nameField.widthAnchor constraintEqualToConstant:250].active=YES;
    [_stack addArrangedSubview:[self row:@[[self label:@"姓名" small:NO],_nameField]]];
    _month=[NSPopUpButton new]; _month.target=self; _month.action=@selector(monthChanged:); _month.accessibilityLabel=@"生日月份";
    _day=[NSPopUpButton new]; _day.accessibilityLabel=@"生日日期";
    _leap=[NSButton checkboxWithTitle:@"闰月生日" target:nil action:nil]; _leap.state=birthday.leapMonth ? NSControlStateValueOn : NSControlStateValueOff;
    [self calendarChanged:nil]; [_month selectItemAtIndex:birthday.month-1]; [self monthChanged:nil]; [_day selectItemAtIndex:birthday.day-1];
    [_stack addArrangedSubview:[self row:@[[self label:@"生日" small:NO],_month,_day]]]; [_stack addArrangedSubview:_leap];
    [_stack addArrangedSubview:[self label:@"无对应闰月时用普通同月；农历三十遇小月用廿九；阳历2月29日遇平年用2月28日。" small:YES]];
    [_stack addArrangedSubview:[self row:@[[self button:@"取消" action:@selector(cancel:)],[self button:@"保存" action:@selector(save:)]]]];
    [self finishPage];
}
- (void)calendarChanged:(id)sender {
    NSInteger month=MAX(0,_month.indexOfSelectedItem); [_month removeAllItems];
    NSArray *lunar=@[@"正月",@"二月",@"三月",@"四月",@"五月",@"六月",@"七月",@"八月",@"九月",@"十月",@"冬月",@"腊月"];
    for (NSInteger i=0;i<12;i++) [_month addItemWithTitle:_calendarType.indexOfSelectedItem==0 ? lunar[i] : [NSString stringWithFormat:@"%zd月",i+1]];
    [_month selectItemAtIndex:month]; _leap.hidden=_calendarType.indexOfSelectedItem!=0; [self monthChanged:nil];
}
- (void)monthChanged:(id)sender {
    NSInteger day=MAX(0,_day.indexOfSelectedItem); [_day removeAllItems];
    NSInteger length=_calendarType.indexOfSelectedItem==0 ? 30 : DaysInMonth(2024,_month.indexOfSelectedItem);
    for (NSInteger i=1;i<=length;i++) [_day addItemWithTitle:[NSString stringWithFormat:@"%zd日",i]];
    [_day selectItemAtIndex:MIN(day,length-1)];
}
- (void)cancel:(id)sender { [self showList]; }
- (void)save:(id)sender {
    _editing.name=[_nameField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    _editing.lunar=_calendarType.indexOfSelectedItem==0; _editing.leapMonth=_editing.lunar && _leap.state==NSControlStateValueOn; _editing.month=_month.indexOfSelectedItem+1; _editing.day=_day.indexOfSelectedItem+1;
    NSError *error; if (![_store saveBirthday:_editing error:&error]) { [self showError:error]; return; }
    [self showList]; if (_store.notificationsEnabled) [_notifications requestPermission];
}
- (void)removeBirthday:(NSButton *)sender {
    NSAlert *alert=[NSAlert new]; alert.messageText=@"删除这条生日记录？"; [alert addButtonWithTitle:@"删除"]; [alert addButtonWithTitle:@"取消"];
    if ([alert runModal]!=NSAlertFirstButtonReturn) return;
    NSError *error; if (![_store deleteBirthday:sender.identifier error:&error]) [self showError:error]; else [self showList];
}
- (void)toggleNotifications:(NSButton *)sender {
    NSError *error; if (![_store setNotificationsEnabled:sender.state==NSControlStateValueOn error:&error]) { [self showError:error]; [self showList]; return; }
    if (_store.notificationsEnabled) [_notifications requestPermission];
}
- (void)allowNotifications:(id)sender { [_notifications requestPermission]; }
- (void)openSettings:(id)sender { [_notifications openSystemSettings]; }
@end
