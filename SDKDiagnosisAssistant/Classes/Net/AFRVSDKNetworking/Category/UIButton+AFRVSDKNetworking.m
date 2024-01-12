// UIButton+AFRVSDKNetworking.m
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "UIButton+AFRVSDKNetworking.h"

#import <objc/runtime.h>

#if TARGET_OS_IOS || TARGET_OS_TV

#import "UIImageView+AFRVSDKNetworking.h"
#import "AFRVSDKImageDownloader.h"

@interface UIButton (_AFRVSDKNetworking)
@end

@implementation UIButton (_AFRVSDKNetworking)

#pragma mark -

static char AFRVSDKImageDownloadReceiptNormal;
static char AFRVSDKImageDownloadReceiptHighlighted;
static char AFRVSDKImageDownloadReceiptSelected;
static char AFRVSDKImageDownloadReceiptDisabled;

static const char * af_rvsdk_imageDownloadReceiptKeyForState(UIControlState state) {
    switch (state) {
        case UIControlStateHighlighted:
            return &AFRVSDKImageDownloadReceiptHighlighted;
        case UIControlStateSelected:
            return &AFRVSDKImageDownloadReceiptSelected;
        case UIControlStateDisabled:
            return &AFRVSDKImageDownloadReceiptDisabled;
        case UIControlStateNormal:
        default:
            return &AFRVSDKImageDownloadReceiptNormal;
    }
}

- (AFRVSDKImageDownloadReceipt *)af_rvsdk_imageDownloadReceiptForState:(UIControlState)state {
    return (AFRVSDKImageDownloadReceipt *)objc_getAssociatedObject(self, af_rvsdk_imageDownloadReceiptKeyForState(state));
}

- (void)af_rvsdk_setImageDownloadReceipt:(AFRVSDKImageDownloadReceipt *)imageDownloadReceipt
                           forState:(UIControlState)state
{
    objc_setAssociatedObject(self, af_rvsdk_imageDownloadReceiptKeyForState(state), imageDownloadReceipt, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

static char AFBackgroundImageDownloadReceiptNormal;
static char AFBackgroundImageDownloadReceiptHighlighted;
static char AFBackgroundImageDownloadReceiptSelected;
static char AFBackgroundImageDownloadReceiptDisabled;

static const char * af_rvsdk_backgroundImageDownloadReceiptKeyForState(UIControlState state) {
    switch (state) {
        case UIControlStateHighlighted:
            return &AFBackgroundImageDownloadReceiptHighlighted;
        case UIControlStateSelected:
            return &AFBackgroundImageDownloadReceiptSelected;
        case UIControlStateDisabled:
            return &AFBackgroundImageDownloadReceiptDisabled;
        case UIControlStateNormal:
        default:
            return &AFBackgroundImageDownloadReceiptNormal;
    }
}

- (AFRVSDKImageDownloadReceipt *)af_rvsdk_backgroundImageDownloadReceiptForState:(UIControlState)state {
    return (AFRVSDKImageDownloadReceipt *)objc_getAssociatedObject(self, af_rvsdk_backgroundImageDownloadReceiptKeyForState(state));
}

- (void)af_rvsdk_setBackgroundImageDownloadReceipt:(AFRVSDKImageDownloadReceipt *)imageDownloadReceipt
                                     forState:(UIControlState)state
{
    objc_setAssociatedObject(self, af_rvsdk_backgroundImageDownloadReceiptKeyForState(state), imageDownloadReceipt, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -

@implementation UIButton (AFRVSDKNetworking)

+ (AFRVSDKImageDownloader *)afrvsdk_sharedImageDownloader {

    return objc_getAssociatedObject([UIButton class], @selector(afrvsdk_sharedImageDownloader)) ?: [AFRVSDKImageDownloader defaultInstance];
}

+ (void)afrvsdk_setSharedImageDownloader:(AFRVSDKImageDownloader *)imageDownloader {
    objc_setAssociatedObject([UIButton class], @selector(afrvsdk_sharedImageDownloader), imageDownloader, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

- (void)afrvsdk_setImageForState:(UIControlState)state
                 withURL:(NSURL *)url
{
    [self afrvsdk_setImageForState:state withURL:url placeholderImage:nil];
}

- (void)afrvsdk_setImageForState:(UIControlState)state
                 withURL:(NSURL *)url
        placeholderImage:(UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self afrvsdk_setImageForState:state withURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)afrvsdk_setImageForState:(UIControlState)state
          withURLRequest:(NSURLRequest *)urlRequest
        placeholderImage:(nullable UIImage *)placeholderImage
                 success:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, UIImage *image))success
                 failure:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, NSError *error))failure
{
    if ([self afrvsdk_isActiveTaskURLEqualToURLRequest:urlRequest forState:state]) {
        return;
    }

    [self afrvsdk_cancelImageDownloadTaskForState:state];

    AFRVSDKImageDownloader *downloader = [[self class] afrvsdk_sharedImageDownloader];
    id <AFRVSDKImageRequestCache> imageCache = downloader.imageCache;

    //Use the image from the image cache if it exists
    UIImage *cachedImage = [imageCache imageforRequest:urlRequest withAdditionalIdentifier:nil];
    if (cachedImage) {
        if (success) {
            success(urlRequest, nil, cachedImage);
        } else {
            [self setImage:cachedImage forState:state];
        }
        [self af_rvsdk_setImageDownloadReceipt:nil forState:state];
    } else {
        if (placeholderImage) {
            [self setImage:placeholderImage forState:state];
        }

        __weak __typeof(self)weakSelf = self;
        NSUUID *downloadID = [NSUUID UUID];
        AFRVSDKImageDownloadReceipt *receipt;
        receipt = [downloader
                   downloadImageForURLRequest:urlRequest
                   withReceiptID:downloadID
                   success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull responseObject) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                       if ([[strongSelf af_rvsdk_imageDownloadReceiptForState:state].receiptID isEqual:downloadID]) {
                           if (success) {
                               success(request, response, responseObject);
                           } else if (responseObject) {
                               [strongSelf setImage:responseObject forState:state];
                           }
                           [strongSelf af_rvsdk_setImageDownloadReceipt:nil forState:state];
                       }

                   }
                   failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                       if ([[strongSelf af_rvsdk_imageDownloadReceiptForState:state].receiptID isEqual:downloadID]) {
                           if (failure) {
                               failure(request, response, error);
                           }
                           [strongSelf  af_rvsdk_setImageDownloadReceipt:nil forState:state];
                       }
                   }];

        [self af_rvsdk_setImageDownloadReceipt:receipt forState:state];
    }
}

#pragma mark -

- (void)afrvsdk_setBackgroundImageForState:(UIControlState)state
                           withURL:(NSURL *)url
{
    [self afrvsdk_setBackgroundImageForState:state withURL:url placeholderImage:nil];
}

- (void)afrvsdk_setBackgroundImageForState:(UIControlState)state
                           withURL:(NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self afrvsdk_setBackgroundImageForState:state withURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)afrvsdk_setBackgroundImageForState:(UIControlState)state
                    withURLRequest:(NSURLRequest *)urlRequest
                  placeholderImage:(nullable UIImage *)placeholderImage
                           success:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, UIImage *image))success
                           failure:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, NSError *error))failure
{
    if ([self afrvsdk_isActiveBackgroundTaskURLEqualToURLRequest:urlRequest forState:state]) {
        return;
    }

    [self afrvsdk_cancelBackgroundImageDownloadTaskForState:state];

    AFRVSDKImageDownloader *downloader = [[self class] afrvsdk_sharedImageDownloader];
    id <AFRVSDKImageRequestCache> imageCache = downloader.imageCache;

    //Use the image from the image cache if it exists
    UIImage *cachedImage = [imageCache imageforRequest:urlRequest withAdditionalIdentifier:nil];
    if (cachedImage) {
        if (success) {
            success(urlRequest, nil, cachedImage);
        } else {
            [self setBackgroundImage:cachedImage forState:state];
        }
        [self af_rvsdk_setBackgroundImageDownloadReceipt:nil forState:state];
    } else {
        if (placeholderImage) {
            [self setBackgroundImage:placeholderImage forState:state];
        }

        __weak __typeof(self)weakSelf = self;
        NSUUID *downloadID = [NSUUID UUID];
        AFRVSDKImageDownloadReceipt *receipt;
        receipt = [downloader
                   downloadImageForURLRequest:urlRequest
                   withReceiptID:downloadID
                   success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull responseObject) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                       if ([[strongSelf af_rvsdk_backgroundImageDownloadReceiptForState:state].receiptID isEqual:downloadID]) {
                           if (success) {
                               success(request, response, responseObject);
                           } else if (responseObject) {
                               [strongSelf setBackgroundImage:responseObject forState:state];
                           }
                           [strongSelf af_rvsdk_setBackgroundImageDownloadReceipt:nil forState:state];
                       }

                   }
                   failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                       if ([[strongSelf af_rvsdk_backgroundImageDownloadReceiptForState:state].receiptID isEqual:downloadID]) {
                           if (failure) {
                               failure(request, response, error);
                           }
                           [strongSelf  af_rvsdk_setBackgroundImageDownloadReceipt:nil forState:state];
                       }
                   }];

        [self af_rvsdk_setBackgroundImageDownloadReceipt:receipt forState:state];
    }
}

#pragma mark -

- (void)afrvsdk_cancelImageDownloadTaskForState:(UIControlState)state {
    AFRVSDKImageDownloadReceipt *receipt = [self af_rvsdk_imageDownloadReceiptForState:state];
    if (receipt != nil) {
        [[self.class afrvsdk_sharedImageDownloader] cancelTaskForImageDownloadReceipt:receipt];
        [self af_rvsdk_setImageDownloadReceipt:nil forState:state];
    }
}

- (void)afrvsdk_cancelBackgroundImageDownloadTaskForState:(UIControlState)state {
    AFRVSDKImageDownloadReceipt *receipt = [self af_rvsdk_backgroundImageDownloadReceiptForState:state];
    if (receipt != nil) {
        [[self.class afrvsdk_sharedImageDownloader] cancelTaskForImageDownloadReceipt:receipt];
        [self af_rvsdk_setBackgroundImageDownloadReceipt:nil forState:state];
    }
}

- (BOOL)afrvsdk_isActiveTaskURLEqualToURLRequest:(NSURLRequest *)urlRequest forState:(UIControlState)state {
    AFRVSDKImageDownloadReceipt *receipt = [self af_rvsdk_imageDownloadReceiptForState:state];
    return [receipt.task.originalRequest.URL.absoluteString isEqualToString:urlRequest.URL.absoluteString];
}

- (BOOL)afrvsdk_isActiveBackgroundTaskURLEqualToURLRequest:(NSURLRequest *)urlRequest forState:(UIControlState)state {
    AFRVSDKImageDownloadReceipt *receipt = [self af_rvsdk_backgroundImageDownloadReceiptForState:state];
    return [receipt.task.originalRequest.URL.absoluteString isEqualToString:urlRequest.URL.absoluteString];
}


@end

#endif
