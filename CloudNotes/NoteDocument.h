//
//  NoteDocument.h
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-4.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import <Foundation/Foundation.h>

// 步骤1, 写delegate protocol
@protocol NoteDocumentDelegate;

@interface NoteDocument : UIDocument

@property (nonatomic, weak) id <NoteDocumentDelegate> delegate;

- (NSInteger)numberOfNotes;
- (void)addNote;

- (NSString*)textForNote:(NSInteger)noteIndex;
- (void)setText:(NSString*)text forNote:(NSInteger)noteIndex;

- (UIImage*)imageForNote:(NSInteger)noteIndex;
- (void)setImage:(UIImage*)image forNote:(NSInteger)noteIndex;

@end

@protocol NoteDocumentDelegate <NSObject>

- (void)noteDocumentContentsUpdated:(NoteDocument*)noteDocument;

@end
