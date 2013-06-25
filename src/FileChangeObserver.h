//
//  FileChangeObserver.h
//
//  Created by Toshiyuki Suzumura on 2013/06/11.
//  Copyright (c) 2013 Toshiyuki Suzumura All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>

typedef enum {
    kFileChangeType_Delete = NOTE_DELETE,
    kFileChangeType_Write = NOTE_WRITE,
    kFileChangeType_DirectoryContentsChanged = kFileChangeType_Write
    //#define   NOTE_WRITE  0x00000002  /* data contents changed */
    //#define   NOTE_EXTEND 0x00000004  /* size increased */
    //#define   NOTE_ATTRIB 0x00000008  /* attributes changed */
    //#define   NOTE_LINK   0x00000010  /* link count changed */
    //#define   NOTE_RENAME 0x00000020  /* vnode was renamed */
    //#define   NOTE_REVOKE 0x00000040  /* vnode access was revoked */
    //#define   NOTE_NONE   0x00000080  /* No specific vnode event: to test for EVFILT_READ activation*/
} FileChangeNotificationType;

@class FileChangeObserver;


@protocol FileChangeObserverDelegate<NSObject>

@required
- (void)fileChanged:(FileChangeObserver*)observer typeMask:(FileChangeNotificationType)type;

@end


@interface FileChangeObserver : NSObject

@property (nonatomic, copy) NSURL * url;
@property (nonatomic, weak) id<FileChangeObserverDelegate> delegate;

+ (instancetype)observerForURL:(NSURL*)url types:(FileChangeNotificationType)types delegate:(id<FileChangeObserverDelegate>)delegate;
- (void)invalidate;

@end


@interface NSString (FileChangeObserver)

+ (NSString*)stringWithKEventFFlags:(FileChangeNotificationType)flags;

@end
