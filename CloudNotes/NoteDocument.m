//
//  NoteDocument.m
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-4.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import "NoteDocument.h"
#import "CloudManager.h"

// 步骤5，因为私有帮助API的需要，枚举定义类型NoteDocumentContentType, 有图像和文字两种类别

enum {
    NoteDocumentContentTypeText,
    NoteDocumentContentTypeImage
};
typedef NSUInteger NoteDocumentContentType;

@implementation NoteDocument

// 步骤2，写下私有变量

{
    NSString* _text;
    id <NoteDocumentDelegate> __weak _delegate;
    NSFileWrapper* _fileWrapper;
    NSMutableArray* _index;
}

@synthesize delegate = _delegate;

// 步骤4，写NoteDocument基本读写API

#pragma mark Basic Reading and Writing

- (void)setupEmptyDocument
{
    // 创建主file wrapper,填充一个子file wrapper index文件
    
    _index = [NSMutableArray array];
    NSFileWrapper* indexFile = [[NSFileWrapper alloc] initRegularFileWithContents:[NSKeyedArchiver archivedDataWithRootObject:_index]];
    indexFile.preferredFilename = @"index";
    _fileWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{@"index" : indexFile}];
}

- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError
{
    // 让读取的新内容-contents成为新的主filewrapper，并更新index文件-_index
    
    if (contents) {
        _fileWrapper = contents;
        _index = [[NSKeyedUnarchiver unarchiveObjectWithData:[[[_fileWrapper fileWrappers] valueForKey:@"index"] regularFileContents]] mutableCopy];
        if (!_index) {
            _index = [NSMutableArray array];
        }
    }
    else {
        [self setupEmptyDocument];
    }
    
    if ([_delegate respondsToSelector:@selector(noteDocumentContentsUpdated:)]) {
        [_delegate noteDocumentContentsUpdated:self];
    }
    
    return YES;
}

- (id)contentsForType:(NSString *)typeName error:(NSError **)outError
{
    // 创建并返回一个主file wrapper的镜像
    
    if (!_fileWrapper) {
        [self setupEmptyDocument];
    }
    return [[NSFileWrapper alloc] initDirectoryWithFileWrappers:_fileWrapper.fileWrappers];
}

// 步骤6 写Document编辑的方法，包括文字和图像

#pragma mark Document Editing

- (NSFileWrapper*)textFileWrapperForNote:(NSInteger)noteIndex
{
    return [[_fileWrapper fileWrappers] valueForKey:[NSString stringWithFormat:@"%@.txt", _index[noteIndex]]];
}

- (NSFileWrapper*)imageFileWrapperForNote:(NSInteger)noteIndex
{
    return [[_fileWrapper fileWrappers] valueForKey:[NSString stringWithFormat:@"%@.jpg", _index[noteIndex]]];
}

- (void)setFileWrapper:(NSFileWrapper*)fileWrapper forNote:(NSInteger)noteIndex forContentType:(NoteDocumentContentType)type
{
    NSFileWrapper* existingFileWrapper = type == NoteDocumentContentTypeText ? [self textFileWrapperForNote:noteIndex] : [self imageFileWrapperForNote:noteIndex];
    fileWrapper.preferredFilename = existingFileWrapper.preferredFilename;
    [_fileWrapper removeFileWrapper:existingFileWrapper];
    [_fileWrapper addFileWrapper:fileWrapper];
}

- (NSString*)textForNote:(NSInteger)noteIndex
{
    NSData* fileData = [[self textFileWrapperForNote:noteIndex] regularFileContents];
    return [fileData length] > 0 ? [NSString stringWithUTF8String:[fileData bytes]] : @"";
}

- (void)setText:(NSString*)text forNote:(NSInteger)noteIndex
{
    NSFileWrapper* newFileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:[NSData dataWithBytes:[text UTF8String] length:[text length]]];
    [self setFileWrapper:newFileWrapper forNote:noteIndex forContentType:NoteDocumentContentTypeText];
}

- (UIImage*)imageForNote:(NSInteger)noteIndex
{
    NSData* fileData = [[self imageFileWrapperForNote:noteIndex] regularFileContents];
    return [UIImage imageWithData:fileData];
}

- (void)setImage:(UIImage*)image forNote:(NSInteger)noteIndex
{
    NSFileWrapper* newFileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:UIImageJPEGRepresentation(image, 1)];
    [self setFileWrapper:newFileWrapper forNote:noteIndex forContentType:NoteDocumentContentTypeImage];
}

- (NSInteger)numberOfNotes
{
    return [_index count];
}

- (void)addNote
{
    NSUUID  *UUID = [NSUUID UUID];
    NSString* noteUUID = [UUID UUIDString];
    [_index addObject:noteUUID];
    
    NSFileWrapper* textFileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:[NSData dataWithBytes:"" length:0]];
    textFileWrapper.preferredFilename = [noteUUID stringByAppendingPathExtension:@"txt"];
    [_fileWrapper addFileWrapper:textFileWrapper];
    
    NSFileWrapper* imageFileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:UIImageJPEGRepresentation([UIImage imageNamed:@"pencil-icon.jpg"], 1)];
    imageFileWrapper.preferredFilename = [noteUUID stringByAppendingPathExtension:@"jpg"];
    [_fileWrapper addFileWrapper:imageFileWrapper];
    
    [_fileWrapper removeFileWrapper:[[_fileWrapper fileWrappers] valueForKey:@"index"]];
    NSFileWrapper* newIndexWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:[NSKeyedArchiver archivedDataWithRootObject:_index]];
    newIndexWrapper.preferredFilename = @"index";
    [_fileWrapper addFileWrapper:newIndexWrapper];
}

// 步骤10，补充preview support，preview不属于NoteDocument，所以不利用NSFileWrapper来写入，而使用NSFileCoordinator, 这里具体没有看懂

#pragma Preview Support

- (NSData*)previewJPEG
{
    return [self numberOfNotes] > 0 ? UIImageJPEGRepresentation([self imageForNote:0], 0.5) : nil;
}

- (BOOL)writeContents:(id)contents andAttributes:(NSDictionary *)additionalFileAttributes safelyToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)saveOperation error:(NSError *__autoreleasing *)outError
{
    // If the superclass succeeds in writing out the document, we can write our preview out here as well.
    // This method is invoked on a background queue inside a file coordination block, so writing is safe.
    
    BOOL success = [super writeContents:contents andAttributes:additionalFileAttributes safelyToURL:url forSaveOperation:saveOperation error:outError];
    
    if (success) {
        NSString* previewFileName = [[self.fileURL lastPathComponent] stringByAppendingPathExtension:@"preview"];
        NSURL* previewFileURL = [[[CloudManager sharedManager] dataDirectoryURL] URLByAppendingPathComponent:previewFileName];
        [[[NSFileCoordinator alloc] initWithFilePresenter:nil] coordinateWritingItemAtURL:previewFileURL options:0 error:nil byAccessor:^(NSURL* writingURL) {
            [[self previewJPEG] writeToURL:writingURL atomically:YES];
        }];
    }
    
    return success;
}

@end
