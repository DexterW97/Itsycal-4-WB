//
//  MoCalCell.m
//
//
//  Created by Sanjay Madan on 12/3/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "MoCalCell.h"
#import "Themer.h"
#import "Sizer.h"

@implementation MoCalCell
{
    NSLayoutConstraint *_textFieldVerticalSpace;
}

- (instancetype)init
{
    CGFloat sz = SizePref.cellSize;
    self = [super initWithFrame:NSMakeRect(0, 0, sz, sz)];
    if (self) {
        _textField = [NSTextField labelWithString:@""];
        [_textField setFont:[NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightMedium]];
        [_textField setTextColor:[NSColor blackColor]];
        [_textField setAlignment:NSTextAlignmentCenter];
        [_textField setTranslatesAutoresizingMaskIntoConstraints:NO];

        [self addSubview:_textField];

        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_textField]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_textField)]];
        
        _textFieldVerticalSpace = [NSLayoutConstraint constraintWithItem:_textField attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:SizePref.cellTextFieldVerticalSpace];
        [self addConstraint:_textFieldVerticalSpace];

        
        _lunarTextField = [NSTextField labelWithString:@""];
        _lunarTextField.font = [NSFont systemFontOfSize:SizePref.lunarFontSize];
        _lunarTextField.alignment = NSTextAlignmentCenter;
        _lunarTextField.translatesAutoresizingMaskIntoConstraints = NO;
        _lunarTextField.hidden = YES;
        [self addSubview:_lunarTextField];
        [NSLayoutConstraint activateConstraints:@[
            [_lunarTextField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_lunarTextField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_lunarTextField.topAnchor constraintEqualToAnchor:_textField.bottomAnchor constant:-1],
        ]];
        REGISTER_FOR_SIZE_CHANGE;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)sizeChanged:(id)sender
{
    [_textField setFont:[NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightMedium]];
    _textFieldVerticalSpace.constant = SizePref.cellTextFieldVerticalSpace;
    [self setLunarDateLabel:_lunarTextField.stringValue];
}

- (void)setLunarDateLabel:(NSString *)label {
    _lunarTextField.stringValue = label;
    // Three-character leap month names must still fit the smallest columns.
    CGFloat fontSize = MIN(SizePref.lunarFontSize, (SizePref.cellSize - 2) / MAX(label.length, 2));
    _lunarTextField.font = [NSFont systemFontOfSize:fontSize];
}

- (void)setShowsLunarDate:(BOOL)showsLunarDate {
    _showsLunarDate = showsLunarDate;
    _lunarTextField.hidden = !showsLunarDate;
}

- (void)setIsToday:(BOOL)isToday {
    _isToday = isToday;
    [self setNeedsDisplay:YES];
}

- (void)setIsHighlighted:(BOOL)isHighlighted {
    _isHighlighted = isHighlighted;
    [self updateTextColor];
}

- (void)setIsInCurrentMonth:(BOOL)isInCurrentMonth {
    _isInCurrentMonth = isInCurrentMonth;
    [self updateTextColor];
}

- (void)setIsSelected:(BOOL)isSelected
{
    if (isSelected != _isSelected) {
        _isSelected = isSelected;
        [self setNeedsDisplay:YES];
    }
}

- (void)setIsHovered:(BOOL)isHovered
{
    if (isHovered != _isHovered) {
        _isHovered = isHovered;
        [self setNeedsDisplay:YES];
    }
}

- (void)setDotColors:(NSArray<NSColor *> *)dotColors
{
    _dotColors = dotColors;
    [self setNeedsDisplay:YES];
}

- (void)updateTextColor {
    self.textField.textColor = self.isInCurrentMonth ? Theme.currentMonthTextColor : Theme.noncurrentMonthTextColor;
    self.lunarTextField.textColor = self.isInCurrentMonth ? Theme.currentMonthTextColor : Theme.noncurrentMonthTextColor;
}

- (void)drawRect:(NSRect)dirtyRect
{
    CGFloat radius = SizePref.cellRadius;
    if (self.isToday) {
        [Theme.todayCellColor set];
        NSRect r = NSInsetRect(self.bounds, 3, 3);
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
        [p setLineWidth:2];
        [p stroke];
    }
    else if (self.isSelected) {
        [Theme.selectedCellColor set];
        NSRect r = NSInsetRect(self.bounds, 3, 3);
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
        [p setLineWidth:2];
        [p stroke];
    }
    else if (self.isHovered) {
        [Theme.hoveredCellColor set];
        NSRect r = NSInsetRect(self.bounds, 3, 3);
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
        [p setLineWidth:2];
        [p stroke];
    }
    if (self.dotColors) {
        CGFloat sz = SizePref.cellSize;
        CGFloat dotWidth = SizePref.cellDotWidth;
        CGFloat dotSpacing = 1.5*dotWidth;
        NSRect r = NSMakeRect(0, 0, dotWidth, dotWidth);
        r.origin.y = self.bounds.origin.y + dotWidth + 2;
        if (self.dotColors.count == 0) {
            [self.textField.textColor set];
            r.origin.x = self.bounds.origin.x + sz/2.0 - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
        }
        else if (self.dotColors.count == 1) {
            [self.dotColors[0] set];
            r.origin.x = self.bounds.origin.x + sz/2.0 - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
        }
        else if (self.dotColors.count == 2) {
            [self.dotColors[0] set];
            r.origin.x = self.bounds.origin.x + sz/2.0 - dotSpacing/2 - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
            
            [self.dotColors[1] set];
            r.origin.x = self.bounds.origin.x + sz/2.0 + dotSpacing/2 - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
        }
        else if (self.dotColors.count == 3) {
            [self.dotColors[0] set];
            r.origin.x = self.bounds.origin.x + sz/2.0 - dotSpacing - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
            
            [self.dotColors[1] set];
            r.origin.x = self.bounds.origin.x + sz/2.0 - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
            
            [self.dotColors[2] set];
            r.origin.x = self.bounds.origin.x + sz/2.0 + dotSpacing - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
        }
    }
}

@end
