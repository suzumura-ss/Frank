//
//  FrankProxy.m
//  kevent_sample
//
//  Created by Toshiyuki Terashita on 13/06/18.
//  Copyright (c) 2013年 suzumura_ss. All rights reserved.
//

#import "FrankProxy.h"
#import "FileChangeObserver.h"


@interface FrankProxy () <FileChangeObserverDelegate>
{
    NSOperationQueue* _queueHTTPRequest;
    FileChangeObserver* _header_observer;
    NSString* _in_header;
    NSString* _in_body;
    NSString* _out_header;
    NSString* _out_body;
}
@end


@implementation FrankProxy

- (void)httpRequestWithHeaderData:(NSData*)headerDatar bodyData:(NSData*)bodyData
{
    NSMutableDictionary* headers = [NSJSONSerialization JSONObjectWithData:headerDatar
                                                                   options:NSJSONReadingMutableContainers
                                                                     error:nil];
    
    NSMutableURLRequest* req = [[NSMutableURLRequest alloc] init];
    [req setURL:[NSURL URLWithString:[headers objectForKey:@"URI"]]];
    [req setHTTPMethod:[headers objectForKey:@"Method"]];
    [headers removeObjectForKey:@"URI"];
    [headers removeObjectForKey:@"Method"];
    
    for (NSString* key in headers.keyEnumerator) {
        [req setValue:[headers objectForKey:key] forHTTPHeaderField:key];
    }
    [req setHTTPBody:bodyData];
    
    printf("\n%s %s\n%s\n%s", req.HTTPMethod.UTF8String, req.URL.description.UTF8String, req.allHTTPHeaderFields.description.UTF8String, req.HTTPBody.description.UTF8String);
    
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:_queueHTTPRequest
                           completionHandler:^(NSURLResponse* res_, NSData* response_body, NSError* response_error) {
                               NSHTTPURLResponse* res = (NSHTTPURLResponse*)res_;
                               printf("=> %d", res.statusCode);
                               
                               [response_body writeToFile:_out_body atomically:NO];
                               NSMutableDictionary* result_headers = [NSMutableDictionary dictionaryWithDictionary:res.allHeaderFields];
                               [result_headers setObject:[NSNumber numberWithInteger:res.statusCode]
                                                  forKey:@"Status"];
                               NSData* header = [NSJSONSerialization dataWithJSONObject:result_headers
                                                                                options:0
                                                                                  error:nil];
                               [header writeToFile:_out_header atomically:NO];
                               NSLog(@"%@ => %d", req.URL, header.length);
                           }];
}



#pragma mark - FileChangeObserverDelegate

- (void)fileChanged:(FileChangeObserver*)observer typeMask:(FileChangeNotificationType)type
{
    NSLog(@"header in.");
    NSData* headerData = [NSData dataWithContentsOfFile:_in_header];
    NSData* bodyData = [NSData dataWithContentsOfFile:_in_body];
    truncate(_in_header.UTF8String, 0);
    truncate(_in_body.UTF8String, 0);
    [self httpRequestWithHeaderData:headerData bodyData:bodyData];
}



#pragma mark - Life cycle.

+ (void)run
{
    static FrankProxy* proxy;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [[FrankProxy alloc] init];
    });
}

- (id)init
{
    self = [super init];
    if (self) {
        _queueHTTPRequest = [[NSOperationQueue alloc] init];
        _queueHTTPRequest.maxConcurrentOperationCount = 1;
        
        NSError* err;
        NSString* dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        _in_header  = [dir stringByAppendingPathComponent:@"in.header"];
        _in_body    = [dir stringByAppendingPathComponent:@"in.body"];
        _out_header = [dir stringByAppendingPathComponent:@"out.header"];
        _out_body   = [dir stringByAppendingPathComponent:@"out.body"];
        
        NSFileManager* fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&err];
        [fm createFileAtPath:_in_header  contents:nil attributes:nil];
        [fm createFileAtPath:_in_body    contents:nil attributes:nil];
        [fm createFileAtPath:_out_header contents:nil attributes:nil];
        [fm createFileAtPath:_out_body   contents:nil attributes:nil];
        
        _header_observer = [FileChangeObserver observerForURL:[[NSURL alloc] initFileURLWithPath:_in_header]
                                                        types:kFileChangeType_Delete|kFileChangeType_Write
                                                     delegate:self];
        NSLog(@"Target: %@/\n", dir);
    }
    return self;
}

@end
