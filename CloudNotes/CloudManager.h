//
//  CloudManager.h
//  CloudNotes
//
//  Created by M.Blomkvist on 12-7-4.
//  Copyright (c) 2012年 M.Blomkvist. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CloudManager : NSObject

// 步骤7， 写CloudManager的变量和公开API

@property (nonatomic) BOOL isCloudEnabled;
@property (nonatomic, readonly) NSURL* dataDirectoryURL;
@property (nonatomic, readonly) NSURL* documentsDirectoryURL;

+ (CloudManager*)sharedManager;

@end

NSString* const ICloudStateUpdatedNotification;
NSString* const UbiquitousContainerFetchingWillBeginNotification;
NSString* const UbiquitousContainerFetchingDidEndNotification;

