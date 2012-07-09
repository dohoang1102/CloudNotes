//
//  DetailViewController.m
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-4.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import "DetailViewController.h"
#import "RootViewController.h"
#import "DocumentStatusView.h"
#import "NoteTableCell.h"

NSString* const DocumentFinishedClosingNotification = @"DocumentFinishedClosingNotification";

@interface DetailViewController ()

@property (strong, nonatomic) UIPopoverController *popoverController;
@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property (nonatomic, strong) IBOutlet UITableView* tableView;

- (void)showConflictButton;
- (void)hideConflictButton;

@end

@implementation DetailViewController
{
    NoteDocument* _document;
    BOOL _createFile;
    UITableView* _tableView;
    DocumentStatusView* _statusView;
    UIBarButtonItem* _conflictButton;
    NSIndexPath* _imageEditingIndexPath;
}

@synthesize popoverController;
@synthesize representedIndex;

- (id)initWithFileURL:(NSURL*)url createNewFile:(BOOL)createNewFile
{
    NSString* nibName = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? @"DetailViewController_iPad" : @"DetailViewController_iPhone";
    self = [super initWithNibName:nibName bundle:nil];
    if (self) {
        _document = [[NoteDocument alloc] initWithFileURL:url];
        self.title = [[url lastPathComponent] stringByDeletingPathExtension];
        _document.delegate = self;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentStateChanged) name:UIDocumentStateChangedNotification object:_document];
        _createFile = createNewFile;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _document.delegate = nil;
    if (self.splitViewController.delegate == self) {
        self.splitViewController.delegate = nil;
    }
}

#pragma mark Document Handling Methods

- (void)documentStateChanged
{
    UIDocumentState state = _document.documentState;
    [_statusView setDocumentState:state];
    
    if (state & UIDocumentStateEditingDisabled) {
        _tableView.userInteractionEnabled = NO;
    }
    else {
        _tableView.userInteractionEnabled = YES;
    }
    
    if (state & UIDocumentStateInConflict) {
        [self showConflictButton];
    }
    else {
        [self hideConflictButton];
    }
}

- (void)noteDocumentContentsUpdated:(NoteDocument *)noteDocument
{
    [_tableView reloadData];
}

- (void)textViewDidChange:(UITextView *)textView
{
    [_document setText:textView.text forNote:[[_tableView indexPathForRowAtPoint:[textView convertPoint:textView.bounds.origin toView:_tableView]] row]];
    [_document updateChangeCount:UIDocumentChangeDone];
}

- (void)addNote
{
    [_document addNote];
    [_tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:[_tableView numberOfRowsInSection:0] inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
}

// 步骤23, 完成xib部分

// 步骤24, 查漏补缺, 发现图像编辑部分没有写

#pragma mark Note Image Editing

- (void)handleImageTapForCell:(NoteTableCell*)cell
{
    _imageEditingIndexPath = [self.tableView indexPathForCell:cell];
    UIImagePickerController* imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    [self.view.window.rootViewController presentViewController:imagePicker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage* image = [info valueForKey:UIImagePickerControllerOriginalImage];
    [[[self.tableView cellForRowAtIndexPath:_imageEditingIndexPath] imageView] setImage:image];
    [[self.tableView cellForRowAtIndexPath:_imageEditingIndexPath] setNeedsLayout];
    [_document setImage:image forNote:_imageEditingIndexPath.row];
    [_document updateChangeCount:UIDocumentChangeDone];
    
    [picker dismissViewControllerAnimated:YES completion:nil];
    _imageEditingIndexPath = nil;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    _imageEditingIndexPath = nil;
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// 步骤25, 查漏补缺, 发现冲突按钮部分没有写

#pragma mark Conflict Handling

- (void)showConflictButton
{
    if (![self.toolbar.items containsObject:_conflictButton]) {
        self.toolbar.items = [self.toolbar.items arrayByAddingObject:_conflictButton];
    }
}

- (void)hideConflictButton
{
    if ([self.toolbar.items containsObject:_conflictButton]) {
        NSMutableArray* barItems = [self.toolbar.items mutableCopy];
        [barItems removeObject:_conflictButton];
        self.toolbar.items = barItems;
    }
}

- (void)conflictButtonPushed
{
    // Any automatic merging logic or presentation of conflict resolution UI should go here.
    // For this sample, I'll just pick the current version and mark the conflict versions as resolved.
    
    for (NSFileVersion* conflictVersion in [NSFileVersion unresolvedConflictVersionsOfItemAtURL:_document.fileURL]) {
        conflictVersion.resolved = YES;
    }
    [NSFileVersion removeOtherVersionsOfItemAtURL:_document.fileURL error:nil];
}

// 步骤20, 开始ViewController生命周期部分

#pragma mark View Controller methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 设置好statusView
    _statusView = [[DocumentStatusView alloc] initWithFrame:CGRectMake(0, 0, 120, 40)];
    UIBarButtonItem* statusItem = [[UIBarButtonItem alloc] initWithCustomView:_statusView];
    
    // 设置好冲突解决按钮
    _conflictButton = [[UIBarButtonItem alloc] initWithTitle:@"Resolve Conflicts" style:UIBarButtonItemStyleBordered target:self action:@selector(conflictButtonPushed)];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.toolbar.items = [self.toolbar.items arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:statusItem, [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addNote)], nil]];
    }
    else {
        self.toolbar.items = [self.toolbar.items arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:statusItem, nil]];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addNote)];
    }
    
    [_tableView registerClass:[NoteTableCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // 创建或者打开文档
    if (_createFile) {
        [_document saveToURL:_document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:nil];
        _createFile = NO;
    }
    else if (_document.documentState & UIDocumentStateClosed) {
        [_document openWithCompletionHandler:^(BOOL success) {
            [_tableView reloadData];
        }];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //_imageEditingIndexPath决定了viewDidAppear时是否处在imagePickerController的状态,如果是的话,
    // 则没有必要关闭文档
    // 如果不是,则说明用户正在导航离开detailViewController,应该关闭文档并发出文档已经关闭的通知供rootViewController做处理,比如如果需要更新preview image
    if (!_imageEditingIndexPath) {
        [_document closeWithCompletionHandler:^(BOOL success) {
            [[NSNotificationCenter defaultCenter] postNotificationName:DocumentFinishedClosingNotification object:self];
        }];
    }
}

// 步骤19, 开始UITableViewDataSource部分

#pragma mark UITableViewDataSource methods

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_document numberOfNotes];
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NoteTableCell* cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textView.text = [_document textForNote:indexPath.row];
    cell.textView.delegate = self;
    cell.imageView.image = [_document imageForNote:indexPath.row];
    cell.delegate = self;
    return cell;
}

// 步骤21, 开始splitViewController delegate部分

#pragma mark UISplitViewControllerDelegate methods

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown : YES;
}

- (BOOL) splitViewController:(UISplitViewController *)svc
    shouldHideViewController:(UIViewController *)vc
               inOrientation:(UIInterfaceOrientation)orientation
{
    return (UIInterfaceOrientationIsPortrait(orientation));
}

- (void)splitViewController:(UISplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController: (UIPopoverController *)pc
{
    barButtonItem.title = @"Notes";
    NSMutableArray *items = [[self.toolbar items] mutableCopy];
    [items insertObject:barButtonItem atIndex:0];
    [self.toolbar setItems:items animated:YES];
    self.popoverController = pc;
}

- (void)splitViewController:(UISplitViewController *)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    NSMutableArray *items = [[self.toolbar items] mutableCopy];
    [items removeObjectAtIndex:0];
    [self.toolbar setItems:items animated:YES];
    self.popoverController = nil;
}

@end

