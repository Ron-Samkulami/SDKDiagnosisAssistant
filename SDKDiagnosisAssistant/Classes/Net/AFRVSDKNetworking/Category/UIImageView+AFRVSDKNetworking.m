// UIImageView+AFRVSDKNetworking.m
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

#import "UIImageView+AFRVSDKNetworking.h"

#import <objc/runtime.h>

#if TARGET_OS_IOS || TARGET_OS_TV

#import "AFRVSDKImageDownloader.h"

@interface UIImageView (_AFRVSDKNetworking)
@property (readwrite, nonatomic, strong, setter = af_rvsdk_setActiveImageDownloadReceipt:) AFRVSDKImageDownloadReceipt *af_rvsdk_activeImageDownloadReceipt;
@end

@implementation UIImageView (_AFRVSDKNetworking)

- (AFRVSDKImageDownloadReceipt *)af_rvsdk_activeImageDownloadReceipt {
    return (AFRVSDKImageDownloadReceipt *)objc_getAssociatedObject(self, @selector(af_rvsdk_activeImageDownloadReceipt));
}

- (void)af_rvsdk_setActiveImageDownloadReceipt:(AFRVSDKImageDownloadReceipt *)imageDownloadReceipt {
    objc_setAssociatedObject(self, @selector(af_rvsdk_activeImageDownloadReceipt), imageDownloadReceipt, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -

@implementation UIImageView (AFRVSDKNetworking)

+ (AFRVSDKImageDownloader *)afrvsdk_sharedImageDownloader {
    return objc_getAssociatedObject([UIImageView class], @selector(afrvsdk_sharedImageDownloader)) ?: [AFRVSDKImageDownloader defaultInstance];
}

+ (void)afrvsdk_setSharedImageDownloader:(AFRVSDKImageDownloader *)imageDownloader {
    objc_setAssociatedObject([UIImageView class], @selector(afrvsdk_sharedImageDownloader), imageDownloader, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

- (void)afrvsdk_setImageWithURL:(NSURL *)url {
    [self afrvsdk_setImageWithURL:url placeholderImage:nil];
}

- (void)afrvsdk_setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self afrvsdk_setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)afrvsdk_setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, NSError *error))failure
{
    if ([urlRequest URL] == nil) {
        self.image = placeholderImage;
        if (failure) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil];
            failure(urlRequest, nil, error);
        }
        return;
    }
    
    if ([self afrvsdk_isActiveTaskURLEqualToURLRequest:urlRequest]) {
        return;
    }
    
    [self afrvsdk_cancelImageDownloadTask];

    AFRVSDKImageDownloader *downloader = [[self class] afrvsdk_sharedImageDownloader];
    id <AFRVSDKImageRequestCache> imageCache = downloader.imageCache;

    //Use the image from the image cache if it exists
    UIImage *cachedImage = [imageCache imageforRequest:urlRequest withAdditionalIdentifier:nil];
    if (cachedImage) {
        if (success) {
            success(urlRequest, nil, cachedImage);
        } else {
            self.image = cachedImage;
        }
        [self afrvsdk_clearActiveDownloadInformation];
    } else {
        if (placeholderImage) {
            self.image = placeholderImage;
        }

        __weak __typeof(self)weakSelf = self;
        NSUUID *downloadID = [NSUUID UUID];
        AFRVSDKImageDownloadReceipt *receipt;
        receipt = [downloader
                   downloadImageForURLRequest:urlRequest
                   withReceiptID:downloadID
                   success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull responseObject) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                       if ([strongSelf.af_rvsdk_activeImageDownloadReceipt.receiptID isEqual:downloadID]) {
                           if (success) {
                               success(request, response, responseObject);
                           } else if (responseObject) {
                               strongSelf.image = responseObject;
                           }
                           [strongSelf afrvsdk_clearActiveDownloadInformation];
                       }

                   }
                   failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                        if ([strongSelf.af_rvsdk_activeImageDownloadReceipt.receiptID isEqual:downloadID]) {
                            if (failure) {
                                failure(request, response, error);
                            }
                            [strongSelf afrvsdk_clearActiveDownloadInformation];
                        }
                   }];

        self.af_rvsdk_activeImageDownloadReceipt = receipt;
    }
}

- (void)afrvsdk_cancelImageDownloadTask {
    if (self.af_rvsdk_activeImageDownloadReceipt != nil) {
        [[self.class afrvsdk_sharedImageDownloader] cancelTaskForImageDownloadReceipt:self.af_rvsdk_activeImageDownloadReceipt];
        [self afrvsdk_clearActiveDownloadInformation];
     }
}

- (void)afrvsdk_clearActiveDownloadInformation {
    self.af_rvsdk_activeImageDownloadReceipt = nil;
}

- (BOOL)afrvsdk_isActiveTaskURLEqualToURLRequest:(NSURLRequest *)urlRequest {
    return [self.af_rvsdk_activeImageDownloadReceipt.task.originalRequest.URL.absoluteString isEqualToString:urlRequest.URL.absoluteString];
}

@end

#endif
