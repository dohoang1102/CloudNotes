//
//  NoteTableCell.h
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-5.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// 步骤15,写NoteTableCell类

@class NoteTableCell;

@protocol NoteTableCellDelegate <NSObject>

- (void)handleImageTapForCell:(NoteTableCell*)cell;

@end

@interface NoteTableCell : UITableViewCell

@property (nonatomic, weak) id <NoteTableCellDelegate> delegate;
@property (nonatomic, readonly) UITextView* textView;

@end
