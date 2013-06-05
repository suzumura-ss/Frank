//
//  GLKView+ImageCapture.m
//  Frank
//
//  Created by Toshiyuki Suzumura on 2013/06/05.
//
//

#import "GLKView+ImageCapture.h"
#import "UIView+ImageCapture.h"

@implementation GLKView (ImageCapture)

- (UIImage *)captureImage {
    if ([self respondsToSelector:@selector(snapshot)]) {
        return [self snapshot];
    }
    return [(UIView*)self captureImage];
}

@end
