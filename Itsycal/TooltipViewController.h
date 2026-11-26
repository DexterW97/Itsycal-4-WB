#import <Cocoa/Cocoa.h>
#import "MoCalTooltipProvider.h"
#import "MoDate.h"
#import "BirthdayStore.h"
@protocol TooltipViewControllerDelegate;
@interface TooltipViewController : NSViewController <MoCalTooltipProvider>
@property (nonatomic, weak) id<TooltipViewControllerDelegate> tooltipDelegate;
@end
@protocol TooltipViewControllerDelegate <NSObject>
- (NSArray *)eventsForDate:(MoDate)date;
- (NSArray<Birthday *> *)birthdaysForDate:(MoDate)date;
@end
