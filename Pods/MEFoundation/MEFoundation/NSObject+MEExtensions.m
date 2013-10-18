//
//  NSObject+MEExtensions.m
//  MEFrameworks
//
//  Created by William Towe on 8/15/12.
//  Copyright (c) 2012 Maestro. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// 
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "NSObject+MEExtensions.h"

#import <objc/runtime.h>

@implementation NSObject (MEExtensions)

+ (void)ME_swapMethod:(SEL)oldSelector withMethod:(SEL)newSelector; {
    Method originalMethod = class_getInstanceMethod(self, oldSelector);
    Method newMethod = class_getInstanceMethod(self, newSelector);
    const char *originalTypeEncoding = method_getTypeEncoding(originalMethod);
    const char *newTypeEncoding = method_getTypeEncoding(newMethod);
    
    NSAssert2(!strcmp(originalTypeEncoding, newTypeEncoding), @"Method type encodings must be the same: %s vs. %s", originalTypeEncoding, newTypeEncoding);
    
    if(class_addMethod(self, oldSelector, method_getImplementation(newMethod), newTypeEncoding)) {
        class_replaceMethod(self, newSelector, method_getImplementation(originalMethod), originalTypeEncoding);
    }
    else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

static char kRepresentedObjectKey;

- (id)ME_representedObject; {
    return objc_getAssociatedObject(self, &kRepresentedObjectKey);
}
- (void)ME_setRepresentedObject:(id)object; {
    objc_setAssociatedObject(self, &kRepresentedObjectKey, object, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
