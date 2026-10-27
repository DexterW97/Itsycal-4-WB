//
//  MoCalGrid.m
//
//
//  Created by Sanjay Madan on 12/3/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "MoCalGrid.h"
#import "MoCalCell.h"
#import "Sizer.h"

@implementation MoCalGrid
{
    NSUInteger _rows, _cols, _hMargin, _vMargin;
}

- (instancetype)initWithRows:(NSUInteger)rows columns:(NSUInteger)cols horizontalMargin:(NSUInteger)hMargin verticalMargin:(NSUInteger)vMargin
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        CGFloat sz = SizePref.cellSize;
        NSMutableArray *cells = [NSMutableArray new];
        for (NSUInteger row = 0; row < rows; row++) {
            for (NSUInteger col = 0; col < cols; col++) {
                CGFloat x = sz * col + hMargin;
                CGFloat y = sz * rows - sz * (row + 1) + vMargin;
                MoCalCell *cell = [MoCalCell new];
                [cell setFrame:NSMakeRect(x, y, sz, self.rowHeight)];
                cell.showsLunarDate = self.showsLunarDates;
                [self addSubview:cell];
                [cells addObject:cell];
            }
        }
        _cells = [NSArray arrayWithArray:cells];
        _rows  = rows;
        _cols  = cols;
        _hMargin = hMargin;
        _vMargin = vMargin;
        _bottomMargin = vMargin;
        
        // Hug the cells tightly
        [self setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
        [self setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        REGISTER_FOR_SIZE_CHANGE;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (CGFloat)rowHeight
{
    return SizePref.cellSize + (self.usesLunarRowHeight ? SizePref.lunarRowExtraHeight : 0);
}

- (void)setUsesLunarRowHeight:(BOOL)usesLunarRowHeight
{
    _usesLunarRowHeight = usesLunarRowHeight;
    [self sizeChanged:nil];
}

- (void)setBottomMargin:(CGFloat)bottomMargin
{
    _bottomMargin = MAX(0, bottomMargin);
    [self sizeChanged:nil];
}

- (void)setShowsLunarDates:(BOOL)showsLunarDates
{
    _showsLunarDates = showsLunarDates;
    for (MoCalCell *cell in _cells) cell.showsLunarDate = showsLunarDates;
}

- (void)addRow
{
    NSMutableArray *cells = [_cells mutableCopy];

    // Shift existing cells up.
    for (MoCalCell *cell in cells) {
        NSRect frame = cell.frame;
        frame.origin.y += self.rowHeight;
        cell.frame = frame;
    }

    // Add new row of cells.
    CGFloat sz = SizePref.cellSize;
    for (NSUInteger col = 0; col < _cols; col++) {
        CGFloat x = sz * col + _hMargin;
        CGFloat y = self.bottomMargin;
        MoCalCell *cell = [MoCalCell new];
        [cell setFrame:NSMakeRect(x, y, sz, self.rowHeight)];
        cell.showsLunarDate = self.showsLunarDates;
        [self addSubview:cell];
        [cells addObject:cell];
    }

    _rows += 1;
    _cells = [NSArray arrayWithArray:cells];
    [self invalidateIntrinsicContentSize];
}

- (void)removeRow
{
    NSMutableArray *cells = [_cells mutableCopy];

    // Remove last row of cells.
    for (NSUInteger col = 0; col < _cols; col++) {
        MoCalCell *cell = [cells lastObject];
        [cell removeFromSuperview];
        [cells removeLastObject];
    }

    // Shift remaining cells down.
    for (MoCalCell *cell in cells) {
        NSRect frame = cell.frame;
        frame.origin.y -= self.rowHeight;
        cell.frame = frame;
    }

    _rows -= 1;
    _cells = [NSArray arrayWithArray:cells];
    [self invalidateIntrinsicContentSize];
}

- (MoCalCell *)cellAtPoint:(NSPoint)point
{
    CGFloat sz = SizePref.cellSize;
    NSInteger col = floorf((point.x - _hMargin) / sz);
    NSInteger row = floorf((point.y - self.bottomMargin) / self.rowHeight);
    row = _rows - row - 1; // flip row coordinate
    if (col < 0 || row < 0 || col >= _cols || row >= _rows) {
        return nil;
    }
    return _cells[_cols * row + col];
}

- (MoCalCell *)cellWithDate:(MoDate)date;
{
    for (MoCalCell *cell in self.cells) {
        if (CompareDates(date, cell.date) == 0) {
            return cell;
        }
    }
    return nil;
}

- (NSRect)cellsRect
{
    return NSMakeRect(_hMargin, self.bottomMargin,
                      NSWidth(self.bounds) - 2 * _hMargin,
                      NSHeight(self.bounds) - _vMargin - self.bottomMargin);
}

- (NSSize)intrinsicContentSize
{
    CGFloat sz = SizePref.cellSize;
    CGFloat width  = sz  * _cols + 2 * _hMargin;
    CGFloat height = self.rowHeight * _rows + _vMargin + self.bottomMargin;
    return NSMakeSize(width, height);
}

- (void)sizeChanged:(id)sender
{
    CGFloat sz = SizePref.cellSize;
    for (NSUInteger row = 0; row < _rows; row++) {
        for (NSUInteger col = 0; col < _cols; col++) {
            CGFloat x = sz * col + _hMargin;
            CGFloat y = self.rowHeight * (_rows - row - 1) + self.bottomMargin;
            MoCalCell *cell = _cells[row*_cols + col];
            [cell setFrame:NSMakeRect(x, y, sz, self.rowHeight)];
            cell.showsLunarDate = self.showsLunarDates;
        }
    }
    [self invalidateIntrinsicContentSize];
}

@end
