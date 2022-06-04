//
//  BZQRCodeCaptureViewController.m
//  Pods
//
//  Created by Hanson on 2022/6/1.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "BZQRCodeCaptureViewController.h"

#define SCREEN_WIDTH  [[UIScreen mainScreen] bounds].size.width
#define SCREEN_HEIGHT [[UIScreen mainScreen] bounds].size.height

@interface BZQRCodeCaptureViewController() <
AVCaptureMetadataOutputObjectsDelegate,
UINavigationControllerDelegate,
UIImagePickerControllerDelegate> {
    void(^_completion)(BOOL, NSString *);
    NSMutableArray *_observers;
    UIView *_viewPreview;
    UIView *_scanView;
    UIImageView * _lineImageView;
    CGRect _lineRect0, _lineRect1;
}

@property (nonatomic, strong, readwrite) UIBarButtonItem * leftBarButtonItem;
@property (nonatomic, strong, readwrite) UIBarButtonItem * rightBarButtonItem;
@property (nonatomic, strong) UIImagePickerController *imagePicker;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic) BOOL isReading;

@end

@implementation BZQRCodeCaptureViewController

- (void)dealloc{
    [self cleanNotifications];
    _observers = nil;
    _viewPreview = nil;
    _scanView = nil;
    _lineImageView = nil;
    _completion = NULL;
    self.imagePicker = nil;
    self.captureSession = nil;
    self.videoPreviewLayer = nil;
    self.leftBarButtonItem = nil;
    self.rightBarButtonItem = nil;
    self.frameImage = nil;
    self.lineImage = nil;
    self.navigationBarTintColor = nil;
}

- (void)setupNotifications{
    if (!_observers) {
        _observers = [NSMutableArray array];
    }
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    __weak BZQRCodeCaptureViewController *SELF = self;
    id o = [center addObserverForName:UIApplicationDidEnterBackgroundNotification
                            object:nil
                             queue:nil
                        usingBlock:^(NSNotification *note) {
        [SELF.imagePicker dismissViewControllerAnimated:NO completion:NULL];
        [SELF cancel];
    }];
    [_observers addObject:o];
}

- (void)cleanNotifications{
    for (id o in _observers) {
        [[NSNotificationCenter defaultCenter] removeObserver:o];
    }
    [_observers removeAllObjects];
}

// 当Pod库未打包上传到远程仓库，本地Example运行调试时使用此方法
- (UIImage *)getLocalBundleImageWithName:(NSString *)name{
    NSBundle *bundle = [NSBundle bundleForClass:[BZQRCodeCaptureViewController class]];
    return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
}

// Pod库上传到远程仓库后，图片会打包成*.bundle资源，引用Pod项目运行时使用此方法
- (UIImage *)getFrameworkBundleImageWithName:(NSString *)name{
    NSBundle *curBundle = [NSBundle bundleForClass:[self class]];   //获取当前所在的Bundle
    NSDictionary *dic = curBundle.infoDictionary;
    NSString *bundleName = dic[@"CFBundleExecutable"];  //获取BundleName
    NSInteger scale = [[UIScreen mainScreen] scale];    //获取屏幕比例
    //拼接图片名称，支持图片名字imageName@2x.png格式
    //NSString *imageName = [NSString stringWithFormat:@"%@@%zdx", name, scale];
    NSString *bundleNamePath = [NSString stringWithFormat:@"%@.bundle", bundleName];
    //路径
    NSString *bundlePath = [[curBundle resourcePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@", bundleNamePath]];
    NSBundle *resourceBundle = [NSBundle bundleWithPath:bundlePath];
    return [UIImage imageNamed:name inBundle:resourceBundle compatibleWithTraitCollection:nil];
}

- (UIImage *)getImageWithName:(NSString *)name{
    UIImage *image = [self getLocalBundleImageWithName:name];
    if (!image) {
        image = [self getFrameworkBundleImageWithName:name];
    }
    return image;
}

- (id)initWithCompletion:(void (^)(BOOL, NSString *))completion{
    self = [super init];
    if (self) {
        _needsScanAnimation = YES;
        _completion = completion;
        _frameImage = [self getImageWithName: @"img_animation_scan_pic"];
        _lineImage = [self getImageWithName: @"img_animation_scan_line"];
        _leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(cancel)];
        
        _rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Album"
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(pickImage)];
    }
    return self;
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    [self startReading];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNotifications];
    
    _imagePicker = [[UIImagePickerController alloc] init];
    _imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    _imagePicker.delegate = self;
    
    if (_navigationBarTintColor) {
        if (self.navigationController) {
            self.navigationController.navigationBar.tintColor = _navigationBarTintColor;
        }
        _imagePicker.navigationBar.tintColor =_navigationBarTintColor;
    }
    
    // Initially make the captureSession object nil.
    _captureSession = nil;
    
    // Set the initial value of the flag to NO.
    _isReading = NO;
    
    [self.navigationItem setLeftBarButtonItem:_leftBarButtonItem];
    [self.navigationItem setRightBarButtonItem:_rightBarButtonItem];
    
    _viewPreview = [[UIView alloc] init];
    [self.view addSubview:_viewPreview];
    [_viewPreview setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_viewPreview
                                                          attribute:NSLayoutAttributeTop
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeTop
                                                         multiplier:1.0
                                                           constant:0.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_viewPreview
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.0
                                                           constant:0.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_viewPreview
                                                          attribute:NSLayoutAttributeLeft
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeLeft
                                                         multiplier:1.0
                                                           constant:0.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_viewPreview
                                                          attribute:NSLayoutAttributeRight
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeRight
                                                         multiplier:1.0
                                                           constant:0.0]];
    if (_needsScanAnimation) {
        _scanView = [[UIView alloc] init];
        [_scanView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.7]];
        [self.view addSubview:_scanView];
        [_scanView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_scanView
                                                              attribute:NSLayoutAttributeTop
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:_viewPreview
                                                              attribute:NSLayoutAttributeTop
                                                             multiplier:1.0
                                                               constant:0.0]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_scanView
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:_viewPreview
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0
                                                               constant:0.0]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_scanView
                                                              attribute:NSLayoutAttributeLeft
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:_viewPreview
                                                              attribute:NSLayoutAttributeLeft
                                                             multiplier:1.0
                                                               constant:0.0]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_scanView
                                                              attribute:NSLayoutAttributeRight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:_viewPreview
                                                              attribute:NSLayoutAttributeRight
                                                             multiplier:1.0
                                                               constant:0.0]];
        
        CGFloat frameWidth = SCREEN_WIDTH * 2 / 3;
        
        UIImageView *imageView = [[UIImageView alloc] init];
        [imageView setBackgroundColor:[UIColor clearColor]];
        [imageView setImage:_frameImage];
        [self.view addSubview:imageView];
        [imageView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:[imageView(==%f)]", frameWidth]
                                                                          options:0
                                                                          metrics:0
                                                                            views:@{@"imageView":imageView}]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"H:[imageView(==%f)]", frameWidth]
                                                                          options:0
                                                                          metrics:0
                                                                            views:@{@"imageView":imageView}]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:imageView
                                                              attribute:NSLayoutAttributeCenterX
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:_viewPreview
                                                              attribute:NSLayoutAttributeCenterX
                                                             multiplier:1.0
                                                               constant:0.0]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:imageView
                                                              attribute:NSLayoutAttributeCenterY
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:_viewPreview
                                                              attribute:NSLayoutAttributeCenterY
                                                             multiplier:1.0
                                                               constant:0.0]];
        
        _lineImageView = [[UIImageView alloc] init];
        CGFloat lineHeight = frameWidth * _lineImage.size.height / _lineImage.size.width;
        _lineRect0 = CGRectMake(0, 0, frameWidth, lineHeight);
        _lineRect1 = CGRectMake(0, frameWidth - lineHeight, frameWidth, lineHeight);
        [_lineImageView setFrame:_lineRect0];
        [_lineImageView setImage:_lineImage];
        [imageView addSubview:_lineImageView];
    }
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    [self setScanViewLayerMask];
    
    if (_needsScanAnimation) {
        [UIView animateWithDuration:2 delay:0 options:UIViewAnimationOptionRepeat animations:^{
            [self->_lineImageView setFrame:self->_lineRect1];
        } completion:^(BOOL finished) {
            [self->_lineImageView setFrame:self->_lineRect0];
            [UIView animateWithDuration:2 delay:0 options:UIViewAnimationOptionRepeat animations:^{
                [self->_lineImageView setFrame:self->_lineRect1];
            } completion:^(BOOL finished) {
                [self->_lineImageView setFrame:self->_lineRect0];
            }];
        }];
    }
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self startReading];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self stopReading];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)setScanViewLayerMask{
    // 原有实现，path和frame中的宽高参考值都是SCREEN_WIDTH和SCREEN_HEIGHT，新版本系统中会引起错位
    // 现将宽高参考值使用viewWillAppear后的width和height值，此宽高值是屏幕实际位置。
    //create path
    CGFloat width = self.view.frame.size.width;
    CGFloat height = self.view.frame.size.height;
    CGFloat frameWidth = width * 2 / 3;
    CGFloat frameHeight = frameWidth;
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, width, height)];
    [path appendPath:[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(width / 6, height / 2 - width / 3, frameWidth, frameHeight) cornerRadius:0] bezierPathByReversingPath]];
    
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.path = path.CGPath;
    [_scanView.layer setMask:shapeLayer];
}

- (void)cancel{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)pickImage{
    [self presentViewController:_imagePicker animated:YES completion:NULL];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    [picker dismissViewControllerAnimated:NO completion:NULL];
    CIContext *context = [CIContext contextWithOptions:nil];
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode
                                              context:context
                                              options:@{CIDetectorAccuracy:CIDetectorAccuracyHigh}];
    CIImage *cgImage = [CIImage imageWithCGImage:image.CGImage];
    NSArray *features = [detector featuresInImage:cgImage];
    CIQRCodeFeature *feature = [features firstObject];
    
    NSString *result = feature.messageString;
    if (_completion) {
        _completion(result != nil, result);
    }
    [self dealWithResult:result];
    [self cancel];
}

- (void)start {
    [self startReading];
}

- (void)stop {
    [self stopReading];
}

- (void)dealWithResult:(NSString *)result {
    
}

#pragma mark - Private method implementation

- (void)startReading {
    if (!_isReading) {
        NSError *error;
        
        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video
        // as the media type parameter.
        AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        // Get an instance of the AVCaptureDeviceInput class using the previous device object.
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
        
        if (input) {
            // Initialize the captureSession object.
            _captureSession = [[AVCaptureSession alloc] init];
            // Set the input device on the capture session.
            [_captureSession addInput:input];
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
            [_captureSession addOutput:captureMetadataOutput];
            
            // Create a new serial dispatch queue.
            dispatch_queue_t dispatchQueue;
            dispatchQueue = dispatch_queue_create("myQueue", NULL);
            [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
            [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
            
            // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
            _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
            [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
            [_videoPreviewLayer setFrame:_viewPreview.layer.bounds];
            [_viewPreview.layer addSublayer:_videoPreviewLayer];
            
            // Start video capture.
            [_captureSession startRunning];
            _isReading = !_isReading;
        } else {
            // If any error occurs, simply log the description of it and don't continue any more.
            NSLog(@"%@", [error localizedDescription]);
            return;
        }
    }
}


- (void)stopReading {
    if (_isReading) {
        // Stop video capture and make the capture session object nil.
        [_captureSession stopRunning];
        _captureSession = nil;
        
        // Remove the video preview layer from the viewPreview view's layer.
        [_videoPreviewLayer removeFromSuperlayer];
        _isReading = !_isReading;
    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate method implementation

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    
    // Check if the metadataObjects array is not nil and it contains at least one object.
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        // Get the metadata object.
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            // If the found metadata is equal to the QR code metadata then update the status label's text,
            // stop reading and change the bar button item's title and the flag's value.
            // Everything is done on the main thread.
            void(^block)(void) = ^(void) {
                [self stopReading];
                [self cancel];
                if (![metadataObj stringValue] || [[metadataObj stringValue] length] == 0) {
                    if (self->_completion) {
                        self->_completion(NO, nil);
                    }
                    [self dealWithResult:nil];
                } else {
                    if (self->_completion) {
                        self->_completion(YES, [metadataObj stringValue]);
                    }
                    [self dealWithResult:[metadataObj stringValue]];
                }
            };
            
            if ([NSThread isMainThread]) {
                block();
            } else {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    block();
                });
            }
        }
    }
}

@end
