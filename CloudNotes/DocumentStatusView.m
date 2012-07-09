//
//  DocumentStatusView.m
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-5.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import "DocumentStatusView.h"

@implementation DocumentStatusView
{
    UIImageView* _circleView;
    UILabel* _unsavedLabel;
}

-(id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _circleView = [[UIImageView alloc] initWithFrame:CGRectMake(8, 8, CGRectGetHeight(frame) - 16, CGRectGetHeight(frame) - 16)];
        _circleView.image = [UIImage imageNamed:@"Green"];
        _unsavedLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetHeight(frame), 2, 80, CGRectGetHeight(frame) - 4)];
        _unsavedLabel.text = @"Unsaved";
        _unsavedLabel.textColor = [UIColor redColor];
        _unsavedLabel.backgroundColor = [UIColor clearColor];
        _unsavedLabel.hidden = YES;
        [self addSubview:_circleView];
        [self addSubview:_unsavedLabel];
        self.backgroundColor = [UIColor clearColor];
    }
    
    return self;
}


-(CGSize)sizeThatFits:(CGSize)size
{
    return CGSizeMake(size.height + 80, size.height);
}

-(void)setDocumentState:(UIDocumentState)documentState
{
    if (documentState & UIDocumentStateSavingError) {
        _unsavedLabel.hidden = NO;
        _circleView.image = [UIImage imageNamed:@"Red"];
    }
    else {
        _unsavedLabel.hidden = YES;
        
        if (documentState & UIDocumentStateInConflict) {
            _circleView.image = [UIImage imageNamed:@"Yellow"];
        }
        else {
            _circleView.image = [UIImage imageNamed:@"Green"];
        }
    }
}

@end
