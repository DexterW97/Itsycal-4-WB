#import <Foundation/Foundation.h>
#import "MoDate.h"

// A Chinese lunar label for a Gregorian civil date (MoDate months are zero-based).
// Uses a fixed China time zone so a date produces the same label on every Mac.
FOUNDATION_EXPORT NSString *MoLunarDateLabel(MoDate date);
