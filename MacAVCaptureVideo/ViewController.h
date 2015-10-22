//
//  ViewController.h
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacVideoCapEngine.h"
#import "MacDatatypes.h"

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
    
    MACCaptureSessionFormat m_capSessionFormat;

    NSAlert *m_alert;
    
    NSFileManager *m_fmFileManager;
    NSString *m_strTmpVideoFile;
    NSTimeInterval m_ulStartCaptureTime;
    NSTimer *m_timerRecordCapture;
}

@property (assign) IBOutlet NSPopUpButton *itmVideoFormat;
- (IBAction)selectVideoFormat:(id)sender;

@property (assign) IBOutlet NSPopUpButton *itmSessionPreset;
- (IBAction)selectSessionPreset:(id)sender;

@property (assign) IBOutlet NSTextField *lblFPS;
@property (assign) IBOutlet NSTextField *tfFPS;

@property (assign) IBOutlet NSButton *btnStart;
- (IBAction)buttonClicked:(id)sender;

@property (assign) IBOutlet NSTextField *tfTimer;

@property (assign) IBOutlet NSImageView *ivPreviewView;

@end

