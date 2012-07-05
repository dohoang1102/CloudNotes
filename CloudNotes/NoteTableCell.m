//
//  NoteTableCell.m
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-5.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import "NoteTableCell.h"

@implementation NoteTableCell
{
    UITapGestureRecognizer* _imageTapGesture;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _textView = [[UITextView alloc] initWithFrame:CGRectMake(50, 5, CGRectGetWidth(self.contentView.bounds) -60, CGRectGetHeight(self.contentView.bounds) - 10)];
        _textView.autoresizingMask = UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleWidth;
        _textView.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_textView];
        
        self.imageView.userInteractionEnabled = YES;
        _imageTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleImageTap:)];
        [self.imageView addGestureRecognizer:_imageTapGesture];
        
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return self;
}

- (void)handleImageTap:(UITapGestureRecognizer*)tapGesture
{
    if (tapGesture.state == UIGestureRecognizerStateRecognized && [_delegate respondsToSelector:@selector(handleImageTapForCell:)]) {
        [_delegate handleImageTapForCell:self];
    }
}

@end
