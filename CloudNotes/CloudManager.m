//
//  CloudManager.m
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-4.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import "CloudManager.h"

static CloudManager* __sharedManager;

NSString* const ICloudStateUpdatedNotification = @"ICloudStateUpdatedNotification";
NSString* const UbiquitousContainerFetchingWillBeginNotification = @"UbiquitousContainerFetchingWillBeginNotification";
NSString* const UbiquitousContainerFetchingDidEndNotification = @"UbiquitousContainerFetchingDidEndNotification";

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

- (id) init
{
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCloudEnabled) name:NSUbiquityIdentityDidChangeNotification object:nil];
        [self updateFileStorageContainerURL:nil];
    }
    
    return self;
}

// 步骤10，非线性的根据isCloudEnabled更新原始数据和文档的存储所在位置
// 并且如果是从本地储存转移到iCloud,这里要负责将所有的本地文件拷贝到iCloud上

- (void)setIsCloudEnabled:(BOOL)isCloudEnabled
{
    if (isCloudEnabled != _isCloudEnabled) {
        _isCloudEnabled = isCloudEnabled;
        NSURL* oldDataDirectoryURL = [self dataDirectoryURL];
        NSURL* oldDocumentDirectoryURL = [self documentsDirectoryURL];
        [self updateFileStorageContainerURL:^{
            if (isCloudEnabled) {
                // 将所有存储在本地沙盘的文档复制到iCloud上
                
                NSArray *localDocuments = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:oldDocumentDirectoryURL includingPropertiesForKeys:nil options:0 error:nil];
                NSArray *localPreviews = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:oldDataDirectoryURL includingPropertiesForKeys:nil options:0 error:nil];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSFileManager* fileManager = [NSFileManager defaultManager];
                    NSURL* newDataDirectoryURL = [self dataDirectoryURL];
                    NSURL* newDocumentDirectoryURL = [self documentsDirectoryURL];
                    
                    for (NSURL* documentURL in localDocuments) {
                        if ([[documentURL pathExtension] isEqualToString:@"note"]) {
                            NSURL* destinationURL = [newDocumentDirectoryURL URLByAppendingPathComponent:[documentURL lastPathComponent]];
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

- (void)updateFileStorageContainerURL:(void(^)(void))completionHandler
{
    @synchronized (self) {
        _dataDirectoryURL = nil;
        if (self.isCloudEnabled) {
            [[NSNotificationCenter defaultCenter] postNotificationName:UbiquitousContainerFetchingWillBeginNotification object:nil];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                _dataDirectoryURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:@"com.millennium.CloudNotes"];
                dispatch_async(dispatch_get_main_queue(), ^{
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
    if ([[NSFileManager defaultManager] ubiquityIdentityToken]) {
        if (self.isCloudEnabled) {
            // 说明设备用户选择使用iCloud,并且使用了一个新的UID token,发射这一通知
            [[NSNotificationCenter defaultCenter] postNotificationName:ICloudStateUpdatedNotification object:nil];
        }
    }
    else {
        //说明设备没有允许iCloud文档，将状态设置为NO，如果此时我们正在使用iCloud, ？？？ 将会发射通知
        self.isCloudEnabled = NO;
    }
}

@end
