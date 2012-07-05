//
//  DetailViewController.h
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-4.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NoteDocument.h"
#import "NoteTableCell.h"

// 步骤17, 在写完DocumentStatusView 和 DocumentTableCell之后,开始写DetailViewController

NSString* const DocumentFinishedClosingNotification; // 当使用本地存储时, 这一文档完成存储通知能够告诉rootViewController合适来更新preview image
@class DocumentStatusView;

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate, UITextViewDelegate, UITableViewDataSource, UITableViewDelegate, NoteDocumentDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, NoteTableCellDelegate>


- (id)initWithFileURL:(NSURL*)url createNewFile:(BOOL)createNewFile;

@property (nonatomic) NSInteger representedIndex;

@end
