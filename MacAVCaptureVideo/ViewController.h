//
//  ViewController.h
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacVideoCapEngine.h"

#include <map>

@interface ViewController : NSViewController <NSTextFieldDelegate>
{
    CMacAVVideoCapEngine *m_pVideoCapEngine;
    AVCaptureDevice *m_pVideoCaptureDevice;

    std::map<NSString*, AVCaptureDeviceFormat*> m_mapVideoFormat;
    AVCaptureDeviceFormat *m_pSelectedVideoFormat;

    NSMutableArray *m_arraySessionPresets;
    NSString *m_pSelectedSessionPreset;

    float m_fMinFPS, m_fMaxFPS, m_fSelectedFPS;

    NSAlert *m_alert;
}
@property (assign) IBOutlet NSPopUpButton *itmVideoFormat;
- (IBAction)selectVideoFormat:(id)sender;

@property (assign) IBOutlet NSPopUpButton *itmSessionPreset;
- (IBAction)selectSessionPreset:(id)sender;

@property (assign) IBOutlet NSTextField *lblFPS;
@property (assign) IBOutlet NSTextField *tfFPS;

@property (assign) IBOutlet NSTextField *tfDumpFile;

@property (assign) IBOutlet NSButton *btnStart;
- (IBAction)startCapture:(id)sender;

@property (assign) IBOutlet NSButton *btnStop;
- (IBAction)stopCapture:(id)sender;

@end

