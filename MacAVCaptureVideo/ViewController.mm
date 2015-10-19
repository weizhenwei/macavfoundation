//
//  ViewController.m
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#import "ViewController.h"

#include "MacLog.h"

@implementation ViewController

@synthesize tfFPS;
@synthesize tfDumpFile;

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    MAC_LOG_INFO("ViewController::viewDidLoad()");

    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (nil == device) {
        return;
    }
    m_pVideoCapEngine = new CMacAVVideoCapEngine();
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)startCapture:(id)sender {
    int iFPS = [tfFPS intValue];
    NSString *strDumpFile = [tfDumpFile stringValue];

    MAC_LOG_INFO("ViewController::startCapture(), FPS = " << iFPS
                 << ", Dump File = " << strDumpFile.UTF8String);
}

- (IBAction)stopCapture:(id)sender {
    int iFPS = [tfFPS intValue];
    NSString *strDumpFile = [tfDumpFile stringValue];

    MAC_LOG_INFO("ViewController::startCapture(), FPS = " << iFPS
                 << ", Dump File = " << strDumpFile.UTF8String);
}
@end
