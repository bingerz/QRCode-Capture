//
//  BZViewController.m
//  QRCode-Capture
//
//  Created by hanbing0604@aliyun.com on 06/02/2022.
//  Copyright (c) 2022 hanbing0604@aliyun.com. All rights reserved.
//

#import "BZViewController.h"
#import "QRCode_Capture/QRCode-Capture.h"

@interface BZViewController ()

@end

@implementation BZViewController

- (void)viewDidLoad{
    [super viewDidLoad];
    [_label setText:@"Please tap Scan Start."];
}

- (IBAction)scan:(id)sender {
    BZQRCodeCaptureViewController *vc = [[BZQRCodeCaptureViewController alloc] initWithCompletion:^(BOOL succeeded, NSString *result) {
        [_label setText:nil];
        if (succeeded) {
            [_label setText:result];
        } else {
            [_label setText:@"Scan failed, please try again."];
        }
    }];
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:NULL];
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
}

@end
