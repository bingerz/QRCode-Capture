//
//  BZQRCodeCaptureViewController.h
//  Pods
//
//  Created by Hanson on 2022/6/1.
//

#ifndef BZQRCodeCaptureViewController_h
#define BZQRCodeCaptureViewController_h

#import <UIKit/UIKit.h>

@interface BZQRCodeCaptureViewController : UIViewController

@property (nonatomic, strong, readonly) UIBarButtonItem *leftBarButtonItem;
@property (nonatomic, strong, readonly) UIBarButtonItem *rightBarButtonItem;
@property (nonatomic, strong) UIColor *navigationBarTintColor;
@property (nonatomic, strong) UIImage *frameImage;
@property (nonatomic, strong) UIImage *lineImage;
@property (nonatomic) BOOL needsScanAnimation;

- (id)initWithCompletion:(void(^)(BOOL succeeded, NSString * result))completion;

#pragma mark - methods for subclass

- (void)start;
- (void)stop;
- (void)dealWithResult:(NSString *)result;
- (void)cancel;

@end

#endif /* BZQRCodeCaptureViewController_h */
