//
//  FileChangeObserver.m
//
//  Created by Toshiyuki Suzumura on 2013/06/11.
//  Copyright (c) 2013 Toshiyuki Suzumura All rights reserved.
//

#import "FileChangeObserver.h"
#include <sys/stat.h>

#undef Assert
#define Assert(COND) { if (!(COND)) { raise( SIGINT ) ; } }


@interface FileChangeObserver ()

@property (nonatomic, readonly)     int kqueue;
@property (nonatomic)               FileChangeNotificationType typeMask;

@end



@implementation FileChangeObserver
@synthesize kqueue = _kqueue ;

+ (instancetype)observerForURL:(NSURL*)url types:(FileChangeNotificationType)types delegate:(id<FileChangeObserverDelegate>)delegate
{
    if (!url) { return nil; }
    
    FileChangeObserver * result = [[[self class] alloc] init];
    result.url = url;
    result.delegate = delegate;
    result.typeMask = types;
    
    [result startObserving];
    return result;
}

-(void)dealloc
{
    [self stopObserving];
}


//
// kqueue_main
//
static void (^kqueue_main)(FileChangeObserver *) = ^(__unsafe_unretained FileChangeObserver* self)
{
    while (true) {
        int fd = open([[self.url path] fileSystemRepresentation], O_EVTONLY);
        if (fd<0) {
            usleep(100);
            continue;
        }
        
        int q = self.kqueue;
        {
            struct kevent event = {
                .ident  = fd,
                .filter = EVFILT_VNODE,
                .flags  = EV_ADD | EV_CLEAR,
                .fflags = self.typeMask,
            };
            int error = kevent(q, &event, 1, NULL, 0, NULL);
            Assert(error == 0);
        }
        
        struct kevent event = {0};
        while (true) {
            int nEvents = kevent(q, NULL, 0, &event, 1, NULL);
            if (nEvents!=1) {
                NSLog(@"kevent() failed - %s", strerror(errno));
                break;
            }
            __block FileChangeNotificationType e = event.fflags;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate fileChanged:self typeMask:e];
            });
            if (e & NOTE_DELETE) {
                NSLog(@"DELETE detected.");
                break;
            }
        }
        close(fd);
    }
};


-(void)stopObserving
{
    @synchronized(self)
    {
        close(self.kqueue);
    }
}

-(void)invalidate
{
    [self stopObserving];
}

-(void)startObserving
{
    @synchronized(self)
    {
        static dispatch_queue_t __q ;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            __q = dispatch_queue_create("file observer queue", DISPATCH_QUEUE_CONCURRENT);
        });
		
        // this is __unsafe_unretained to avoid retaining 'self'.
        // using __weak isn't a strong enough to prevent ARC from retaining 'self'.
        // This allows the observer to be torn down simply be releasing it,
        // instead of requiring the client to invoke -invalidate.
        __unsafe_unretained id unsafe_self = self ;
        dispatch_async( __q, ^{
            kqueue_main(unsafe_self);
        });
    }
}

-(int)kqueue
{
    if (!_kqueue) { _kqueue = kqueue(); }
    return _kqueue;
}

@end


@implementation NSString (FileChangeObserver)

+ (NSString*)stringWithKEventFFlags:(FileChangeNotificationType)flags
{
    NSMutableArray * array = [NSMutableArray array];
    static const struct {
        const char* name;
    } bitNames[] = {
        { "NOTE_DELETE" },
        { "NOTE_WRITE" },
        { "NOTE_EXTEND" },
        { "NOTE_ATTRIB" },
        { "NOTE_LINK" },
        { "NOTE_RENAME" },
        { "NOTE_REVOKE" },
        { "NOTE_NONE" }
    };
    
    for(int index=0, count=sizeof(bitNames)/sizeof(bitNames[0]); index<count; ++index) {
        if ((flags&(1<<index))!=0) {
            [array addObject:[NSString stringWithCString:bitNames[index].name encoding:NSUTF8StringEncoding]];
        }
    }
    return [array componentsJoinedByString:@" "];
}

@end