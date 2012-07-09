//
//  CloudManager.m
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-4.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import "CloudManager.h"

NSString* const ICloudStateUpdatedNotification = @"ICloudStateUpdatedNotification";
NSString* const UbiquitousContainerFetchingWillBeginNotification = @"UbiquitousContainerFetchingWillBeginNotification";
NSString* const UbiquitousContainerFetchingDidEndNotification = @"UbiquitousContainerFetchingDidEndNotification";

static CloudManager* __sharedManager;

@implementation CloudManager
{
    BOOL _isCloudEnabled;
    NSURL* _dataDirectoryURL;
}

@synthesize isCloudEnabled = _isCloudEnabled;
@synthesize dataDirectoryURL = _dataDirectoryURL;

+ (CloudManager*)sharedManager
{
    if (!__sharedManager) {
        __sharedManager = [[CloudManager alloc] init];
    }
    
    return __sharedManager;
}

- (id)init
{
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateICloudEnabled:) name:NSUbiquityIdentityDidChangeNotification object:nil];
        [self updateFileStorageContainerURL:nil];
    }
    
    return self;
}

// 步骤10，非线性的根据isCloudEnabled更新原始数据和文档的存储所在位置
// 并且如果是从本地储存转移到iCloud,这里要负责将所有的本地文件拷贝到iCloud上

- (void)setIsCloudEnabled:(BOOL)isCloudEnabled
{
    // Asynchronously update our data directory URL and documents directory URL
    // If we're enabling cloud storage, we move any local documents into the cloud container after the URLs are updated.
    // 将所有存储在本地沙盘的文档复制到iCloud上

    
    if (isCloudEnabled != _isCloudEnabled) {
        _isCloudEnabled = isCloudEnabled;
        NSURL* oldDataDirectoryURL = [self dataDirectoryURL];
        NSURL* oldDocumentsDirectoryURL = [self documentsDirectoryURL];
        [self updateFileStorageContainerURL:^(void) {
            if (isCloudEnabled) {
                // Now move any existing local documents into iCloud.
                
                NSArray* localDocuments = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:oldDocumentsDirectoryURL includingPropertiesForKeys:nil options:0 error:nil];
                NSArray* localPreviews = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:oldDataDirectoryURL includingPropertiesForKeys:nil options:0 error:nil];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                    NSFileManager* fileManager = [[NSFileManager alloc] init];
                    NSURL* newDataDirectoryURL = [self dataDirectoryURL];
                    NSURL* newDocumentsDirectoryURL = [self documentsDirectoryURL];
                    
                    for (NSURL* documentURL in localDocuments) {
                        if ([[documentURL pathExtension] isEqualToString:@"note"]) {
                            NSURL* destinationURL = [newDocumentsDirectoryURL URLByAppendingPathComponent:[documentURL lastPathComponent]];
                            [fileManager setUbiquitous:YES itemAtURL:documentURL destinationURL:destinationURL error:nil];
                        }
                    }
                    
                    for (NSURL* previewURL in localPreviews) {
                        if ([[previewURL pathExtension] isEqualToString:@"preview"]) {
                            NSURL* destinationURL = [newDataDirectoryURL URLByAppendingPathComponent:[previewURL lastPathComponent]];
                            [fileManager setUbiquitous:YES itemAtURL:previewURL destinationURL:destinationURL error:nil];
                        }
                    }
                });
            }
        }];
        [[NSNotificationCenter defaultCenter] postNotificationName:ICloudStateUpdatedNotification object:nil];
    }
}

- (NSURL*)documentsDirectoryURL
{
    return [_dataDirectoryURL URLByAppendingPathComponent:@"Documents"];
}

// 步骤8，更新文件存储位置URL，并且在使用iCloud时发射寻找iCloud Ubiquity Container ID's URL开始结束的通知

- (void)updateFileStorageContainerURL:(void (^)(void))completionHandler
{
    // Perform the asynchronous update of the data directory and document directory URLs
    
    @synchronized (self) {
        _dataDirectoryURL = nil;
        if (self.isCloudEnabled) {
            [[NSNotificationCenter defaultCenter] postNotificationName:UbiquitousContainerFetchingWillBeginNotification object:nil];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                _dataDirectoryURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:@"9M6NFDBTPN.com.millennium.CloudNotes"];
                dispatch_sync(dispatch_get_main_queue(), ^(void) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:UbiquitousContainerFetchingDidEndNotification object:nil];
                    
                    if (completionHandler) {
                        completionHandler();
                    }
                });
            });
        }
        else {
            _dataDirectoryURL = [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
        }
    }
}

// 步骤9，更新isCloudEnabled的帮助方法，并发射出通知供此程序的其他部分使用

- (void)updateICloudEnabled:(NSNotification*)notification
{
    // Broadcast our own notification for iCloud state changes that other parts of our application can use and know the CloudManager has updated itself for the new state when they receive the notication.
    
    if ([[NSFileManager defaultManager] ubiquityIdentityToken]) {
        if (self.isCloudEnabled) {
            // If we're using iCloud already and we moved to a new token, broadcast a state change for that
            [[NSNotificationCenter defaultCenter] postNotificationName:ICloudStateUpdatedNotification object:nil];
        }
    }
    else {
        // If there is no tken now, set our state to NO, which will broadcast a state change if we were using iCloud
        self.isCloudEnabled = NO;
    }
}

@end
