#import "TooltipViewController.h"
#import "AgendaViewController.h"
#import "Sizer.h"
@implementation TooltipViewController {
    AgendaViewController *_agenda;
    NSTextField *_birthdays;
    NSCalendar *_calendar;
    NSLayoutConstraint *_agendaHeight;
}
- (void)loadView {
    _calendar=[NSCalendar autoupdatingCurrentCalendar];
    _agenda=[AgendaViewController new]; _agenda.nsCal=_calendar; [self addChildViewController:_agenda];
    _birthdays=[NSTextField wrappingLabelWithString:@""]; _birthdays.textColor=NSColor.systemRedColor;
    NSStackView *stack=[NSStackView stackViewWithViews:@[_birthdays,_agenda.view]];
    stack.orientation=NSUserInterfaceLayoutOrientationVertical; stack.alignment=NSLayoutAttributeLeading; stack.spacing=4;
    [_birthdays.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-8].active=YES;
    [_agenda.view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;
    _agendaHeight=[_agenda.view.heightAnchor constraintEqualToConstant:0]; _agendaHeight.active=YES;
    self.view=stack;
}
- (BOOL)toolTipForDate:(MoDate)date {
    (void)self.view;
    NSArray *events=[self.tooltipDelegate eventsForDate:date];
    NSArray *birthdays=[self.tooltipDelegate birthdaysForDate:date];
    NSMutableArray *lines=[NSMutableArray new];
    for (Birthday *b in birthdays) [lines addObject:[@"🎂 " stringByAppendingString:b.name]];
    _birthdays.font=[NSFont systemFontOfSize:SizePref.fontSize];
    _birthdays.stringValue=[lines componentsJoinedByString:@"\n"]; _birthdays.hidden=lines.count==0;
    _agenda.tv.enableHover=NO;
    _agenda.tv.enclosingScrollView.hasVerticalScroller=NO;
    _agenda.events=events; [_agenda reloadData]; _agenda.view.hidden=events.count==0;
    CGFloat height=0;
    for (NSInteger row=0;row<_agenda.tv.numberOfRows;row++) height += [_agenda tableView:_agenda.tv heightOfRow:row];
    _agendaHeight.constant=height;
    return events.count>0 || birthdays.count>0;
}
@end
