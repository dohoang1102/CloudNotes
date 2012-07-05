//
//  RootViewController.m
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-4.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import "RootViewController.h"
#import "DetailViewController.h"
#import "CloudManager.h"

// 步骤12，一个文档帮助类

@interface FileRepresentation : NSObject

@property (nonatomic, readonly) NSString* fileName;
@property (nonatomic, readonly) NSURL* url;
@property (nonatomic, retain) NSURL* previewURL;

- (id)initWithFileName:(NSString*)fileName url:(NSURL*)url;

@end

@implementation FileRepresentation

- (id)initWithFileName:(NSString *)fileName url:(NSURL *)url
{
    self = [super init];
    if (self) {
        _fileName = fileName;
        _url = url;
    }
    
    return self;
}

- (BOOL)isEqual:(FileRepresentation*)object
{
    return [object isKindOfClass:[FileRepresentation class]] && [_fileName isEqual:object.fileName];
}

@end

@interface RootViewController ()

// 步骤13，写rootViewController的变量
{
    NSMetadataQuery* _query;
    NSMetadataQuery* _previewQuery;
    NSMutableArray* _fileList;
    NSMutableDictionary* _previewLoadingOperations;
}

@end

@implementation RootViewController

// 步骤14, 阅读了所有的代码，读懂了rootViewController,抄写代码

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = @"Notes";
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            self.clearsSelectionOnViewWillAppear = NO;
            self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
        }
        
        _fileList = [NSMutableArray array];
        _previewLoadingOperations = [NSMutableDictionary dictionary];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCloudEnabled:) name:ICloudStateUpdatedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentFinishedClosing:) name:DocumentFinishedClosingNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [_query stopQuery];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateFileList
{
    // 如果当前是iCloud,创建并启动一个metadata query
    // 如果当前是本地存储利用NSFileManager APIs来创建fileList
    
    [_fileList removeAllObjects];
    [_query stopQuery];
    
    if ([[CloudManager sharedManager] isCloudEnabled]) {
        if (_query) {
            [_query startQuery];
        }
        else {
            _query = [[NSMetadataQuery alloc] init];
            [_query setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUbiquitousDataScope,NSMetadataQueryUbiquitousDocumentsScope, nil]];
            [_query setPredicate:[NSPredicate predicateWithFormat:@"%K LIKE '*.note*'",NSMetadataItemFSNameKey]];
            NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
            [notificationCenter addObserver:self selector:@selector(fileListReceived) name:NSMetadataQueryDidFinishGatheringNotification object:_query];
            [notificationCenter addObserver:self selector:@selector(fileListReceived) name:NSMetadataQueryDidUpdateNotification object:_query];
            [_query startQuery];
        }
    }
    else {
        NSURL* documentDirectoryURL = [[CloudManager sharedManager] documentsDirectoryURL];
        NSArray* localDocuments = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:documentDirectoryURL includingPropertiesForKeys:nil options:0 error:nil];
        NSURL* dataDirectoryURL = [[CloudManager sharedManager] dataDirectoryURL];
        for (NSURL* document in localDocuments) {
            if ([document.pathExtension isEqualToString:@"note"]) {
                FileRepresentation* filePresentation = [[FileRepresentation alloc] initWithFileName:[document lastPathComponent] url:document];
                NSString* previewFilePath = [[dataDirectoryURL path] stringByAppendingPathComponent:[[document lastPathComponent] stringByAppendingPathComponent:@"preview"]];
                if ([[NSFileManager defaultManager] fileExistsAtPath:previewFilePath]) {
                    filePresentation.previewURL = [NSURL fileURLWithPath:previewFilePath];
                }
                [_fileList addObject:filePresentation];
            }
        }
    }
}

- (void)updateCloudEnabled
{
    // 如果iCloud状态改变，比如，账号注销的发生，关闭正被打开的DetailViewController并且更新fileList
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self.navigationController popToRootViewControllerAnimated:NO];
    }
    else {
        DetailViewController* emptyDetailViewController = [[DetailViewController alloc] initWithNibName:@"DetailViewController_iPad" bundle:nil];
        self.splitViewController.viewControllers = [NSArray arrayWithObjects:self.navigationController, emptyDetailViewController, nil];
    }
    
    [self updateFileList];
    [self.tableView reloadData];
}

- (void)documentFinishedClosing:(NSNotification*)notification
{
    if (![[CloudManager sharedManager] isCloudEnabled]) {
        // 当使用iCloud, 可以依赖metadata quries 来更新fileList，但是当使用本地存储时，就要利用这个通知来更新了
        [self updateFileList];
        [self loadPreviewImageForIndexPath:[NSIndexPath indexPathForRow:[(DetailViewController*)notification.object representedIndex] inSection:0]];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.allowsSelectionDuringEditing = NO;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"previewcell"];
    UIBarButtonItem* plusButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(createFile:)];
    self.navigationItem.rightBarButtonItem = plusButton;
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    [self updateFileList];
}

- (void)createFile
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"New File" message:@"Enter file name" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Done", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

- (void)selectFileAtIndexPath:(NSIndexPath*)indexPath create:(BOOL)create
{
    DetailViewController* detailViewController = [[DetailViewController alloc] initWithFileURL:[[_fileList objectAtIndex:indexPath.row] url] createNewFile:create];
    detailViewController.representedIndex = indexPath.row;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.splitViewController.viewControllers = [NSArray arrayWithObjects:self.navigationController, detailViewController, nil];
    }
    else {
        [self.navigationController pushViewController:detailViewController animated:YES];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != alertView.cancelButtonIndex) {
        NSString* fileName = [[alertView textFieldAtIndex:0] text];
        NSURL* fileURL = [[[CloudManager sharedManager] documentsDirectoryURL] URLByAppendingPathComponent:[fileName stringByAppendingPathExtension:@"note"]];
        FileRepresentation* fileRepresentation = [[FileRepresentation alloc] initWithFileName:fileName url:fileURL];
        [_fileList addObject:fileRepresentation];
        [_fileList sortUsingComparator:^NSComparisonResult(FileRepresentation* firstObject, FileRepresentation* secondObject) {
            return [firstObject.fileName compare:secondObject.fileName];
        }];
        NSInteger insertionRow = [_fileList indexOfObject:fileRepresentation];
        NSIndexPath* newFileIndexPath = [NSIndexPath indexPathForRow:insertionRow inSection:0];
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newFileIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView selectRowAtIndexPath:newFileIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        [self selectFileAtIndexPath:newFileIndexPath create:YES];
    }
}

- (void)fileListReceived
{
    // 更新从metadata query取得的file list信息
    // 当发现preview文件时，启动非线性下载preview图像
    
    NSIndexPath* currentSelection = [self.tableView indexPathForSelectedRow];
    NSString* selectedFileName = currentSelection ? [[_fileList objectAtIndex:currentSelection.row] fileName] : nil;
    NSInteger newSelectionRow = currentSelection ? currentSelection.row : NSNotFound;
    NSMutableArray* oldFileList = [_fileList mutableCopy];
    
    [_fileList removeAllObjects];
    NSArray* results = [[_query results] sortedArrayUsingComparator:^NSComparisonResult(NSMetadataItem* firstObject, NSMetadataItem* secondObject) {
        NSString* firstFileName = [firstObject valueForAttribute:NSMetadataItemFSNameKey];
        NSString* secondFileName = [secondObject valueForAttribute:NSMetadataItemFSNameKey];
        NSComparisonResult result = [firstFileName.pathExtension compare:secondFileName.pathExtension];
        return result == NSOrderedSame ? [firstFileName compare:secondFileName] : result;
    }];
    
    for (NSMetadataItem *result in results) {
        NSURL* fileURL = [result valueForAttribute:NSMetadataItemFSNameKey];
        NSString* fileName = [result valueForAttribute:NSMetadataItemDisplayNameKey];
        
        if ([[fileURL pathExtension] isEqualToString:@"note"]) {
            if ([selectedFileName isEqualToString:fileName]) {
                newSelectionRow = [_fileList count];
            }
            
            FileRepresentation* fileRepresentation = [[FileRepresentation alloc] initWithFileName:fileName url:fileURL];
            [_fileList addObject:fileRepresentation];
        }
        else if ([[fileURL pathExtension] isEqualToString:@"preview"]) {
            [_fileList enumerateObjectsUsingBlock:^(FileRepresentation* fileRepresentation, NSUInteger index, BOOL *stop) {
                if ([[fileName stringByDeletingPathExtension] isEqualToString:fileRepresentation.fileName]) {
                    if (!fileRepresentation.previewURL) {
                        fileRepresentation.previewURL = [result valueForAttribute:NSMetadataItemURLKey];
                        [self loadPreviewImageForIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
                    }
                    
                    *stop = YES;
                }
            }];
        }
    }
    
    [_fileList sortUsingComparator:^(FileRepresentation* file1, FileRepresentation* file2) {
        return [file1.fileName compare:file2.fileName];
    }];

    NSMutableArray* insertionRows = [NSMutableArray array];
    NSMutableArray* deletionRows = [NSMutableArray array];

    [_fileList enumerateObjectsUsingBlock:^(FileRepresentation* newFile, NSUInteger newIndex, BOOL *stop) {
        if (![oldFileList containsObject:newFile]) {
            [insertionRows addObject:[NSIndexPath indexPathForRow:newIndex inSection:0]];
        }
    }];
    
    [oldFileList enumerateObjectsUsingBlock:^(FileRepresentation* oldFile, NSUInteger oldIndex, BOOL *stop) {
        if (![_fileList containsObject:oldFileList]) {
            [deletionRows addObject:[NSIndexPath indexPathForRow:oldIndex inSection:0]];
        }
    }];
    
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:deletionRows withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView insertRowsAtIndexPaths:insertionRows withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
    
    if (newSelectionRow != NSNotFound) {
        NSIndexPath* selectionPath = [NSIndexPath indexPathForRow:newSelectionRow inSection:0];
        [self.tableView selectRowAtIndexPath:selectionPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

- (void)loadPreviewImageForIndexPath:(NSIndexPath*)indexPath
{
    FileRepresentation* fileRepresentation = _fileList[indexPath.row];
    NSBlockOperation* previewLoadingOperation = [NSBlockOperation blockOperationWithBlock:^(void) {
        UITableViewCell* visibleCell = [self.tableView cellForRowAtIndexPath:indexPath];
        visibleCell.imageView.image = [UIImage imageWithContentsOfFile:[fileRepresentation.previewURL path]];
        [visibleCell setNeedsLayout];
        [_previewLoadingOperations removeObjectForKey:indexPath];
    }];
    _previewLoadingOperations[indexPath] = previewLoadingOperation;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [fileCoordinator coordinateReadingItemAtURL:fileRepresentation.previewURL options:0 error:nil byAccessor:^(NSURL *newURL) {
            [[NSOperationQueue mainQueue] addOperation:previewLoadingOperation];
        }];
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_fileList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"previewcell" forIndexPath:indexPath];
    
    // Configure the cell.
    FileRepresentation* fileRepresentation = _fileList[indexPath.row];
    cell.textLabel.text = fileRepresentation.fileName;
    cell.imageView.image = nil;
    [self loadPreviewImageForIndexPath:indexPath];
    
    return cell;
}

- (void)tableView:(UITableView*)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // If we're done with the cell, we can cancel any outstanding loading operations.
    [_previewLoadingOperations[indexPath] cancel];
    [_previewLoadingOperations removeObjectForKey:indexPath];
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    CloudManager* cloudManager = [CloudManager sharedManager];
    return cloudManager ? @"iCloud Notes" : @"Local Notes";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self selectFileAtIndexPath:indexPath create:NO];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Perform an asynchronous coordinated delete of the file and its preview.
    
    NSURL* fileURL = [[_fileList objectAtIndex:indexPath.row] url];
    NSURL* previewURL = [[_fileList objectAtIndex:indexPath.row] previewURL];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [fileCoordinator coordinateWritingItemAtURL:fileURL options:NSFileCoordinatorWritingForDeleting error:nil byAccessor:^(NSURL* writingURL) {
            NSFileManager* fileManager = [[NSFileManager alloc] init];
            [fileManager removeItemAtURL:writingURL error:nil];
        }];
        
        if (previewURL) {
            [fileCoordinator coordinateWritingItemAtURL:previewURL options:NSFileCoordinatorWritingForDeleting error:nil byAccessor:^(NSURL* writingURL) {
                NSFileManager* fileManager = [[NSFileManager alloc] init];
                [fileManager removeItemAtURL:writingURL error:nil];
            }];
        }
        
    });
    [_fileList removeObjectAtIndex:indexPath.row];
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ![indexPath isEqual:[tableView indexPathForSelectedRow]];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    if (editing && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.splitViewController.viewControllers = [NSArray arrayWithObjects:self.navigationController, [[DetailViewController alloc] initWithNibName:@"DetailViewController_iPad" bundle:nil], nil];
    }
    
    [super setEditing:editing animated:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown : YES;
}

@end
