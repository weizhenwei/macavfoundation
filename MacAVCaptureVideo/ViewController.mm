//
//  ViewController.m
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "MacDatatypes.h"
#import "MacLog.h"

#import "ViewController.h"

@implementation ViewController

@synthesize itmVideoFormat;
@synthesize itmSessionPreset;
@synthesize lblFPS;
@synthesize tfFPS;
@synthesize btnStart;

- (long)setupCaptureDevice {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (nil == device) {
        MAC_LOG_FATAL("ViewController::setupCaptureDevice(), couldn't setup AVCaptureDevice.");
        return MAC_S_FALSE;
    }
    
    m_pVideoCaptureDevice = device;
    return MAC_S_OK;
}

- (long)setupVideoFormat {
    [itmVideoFormat removeAllItems];
    m_mapVideoFormat.clear();

    bool bDefault = false;
    AVCaptureDeviceFormat *defaultFormat = nil;
    NSString *defaultStrFormat = @"Y'CbCr 4:2:0 - 420v, 1280 x 720";
    for ( AVCaptureDeviceFormat *format in [m_pVideoCaptureDevice formats] ) {
        NSString *formatName = (NSString *)CMFormatDescriptionGetExtension(
                                    [format formatDescription], kCMFormatDescriptionExtension_FormatName);
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(
                                        (CMVideoFormatDescriptionRef)[format formatDescription]);
        NSString *videoformat = [NSString stringWithFormat:@"%@, %d x %d",
                                 formatName, dimensions.width, dimensions.height];
        if (!bDefault && [videoformat isEqualToString:defaultStrFormat]) {
            bDefault = true;
            defaultFormat = format;
        }
        m_mapVideoFormat.insert(std::pair<NSString*, AVCaptureDeviceFormat*>(videoformat, format));
        [itmVideoFormat addItemWithTitle:videoformat];
    }
    if (m_mapVideoFormat.size() <= 0) {
        MAC_LOG_ERROR("ViewController::setupVideoFormat(), no AVCaptureDeviceFormat available!");
        return MAC_S_FALSE;
    }

    // set default video format;
    if (bDefault) {
        [itmVideoFormat setTitle:defaultStrFormat];
        m_pSelectedVideoFormat = defaultFormat;
    } else {
        [itmVideoFormat setTitle:m_mapVideoFormat.begin()->first];
        m_pSelectedVideoFormat = m_mapVideoFormat.begin()->second;
    }

    return MAC_S_OK;
}

- (long)setupSessionPreset {
    [itmSessionPreset removeAllItems];
    m_arraySessionPresets = [[NSMutableArray alloc] init];
    if (m_arraySessionPresets == nil) {
        MAC_LOG_ERROR("ViewController::setupSessionPreset(), alloc NSMutableArray failed!");
        return MAC_S_FALSE;
    }
    
    NSArray *arrayPresets = [NSArray arrayWithObjects:
                             AVCaptureSessionPresetLow,
                             AVCaptureSessionPresetMedium,
                             AVCaptureSessionPresetHigh,
                             AVCaptureSessionPreset320x240,
                             AVCaptureSessionPreset352x288,
                             AVCaptureSessionPreset640x480,
                             AVCaptureSessionPreset960x540,
                             AVCaptureSessionPreset1280x720,
                             AVCaptureSessionPresetPhoto,
                             nil];
    for (NSString *sessionPreset in arrayPresets) {
        if ([m_pVideoCaptureDevice supportsAVCaptureSessionPreset:sessionPreset]) {
            [m_arraySessionPresets addObject:sessionPreset];
            [itmSessionPreset addItemWithTitle:sessionPreset];
        }
    }
    if ([m_arraySessionPresets count] <= 0) {
        MAC_LOG_ERROR("ViewController::setupSessionPreset(), no supported session preset available!");
        return MAC_S_FALSE;
    }

    // set default session preset;
    if ([m_arraySessionPresets containsObject:AVCaptureSessionPreset1280x720]) {
        m_pSelectedSessionPreset = AVCaptureSessionPreset1280x720;
        [itmSessionPreset setTitle:m_pSelectedSessionPreset];
    } else {
        m_pSelectedSessionPreset = [m_arraySessionPresets firstObject];
        [itmSessionPreset setTitle:m_pSelectedSessionPreset];
    }

    return MAC_S_OK;
}

- (long)setupFPS {
    m_fMaxFPS = m_fMaxFPS = m_fSelectedFPS = 0.0f;
    if (m_pSelectedVideoFormat == nil) {
        MAC_LOG_ERROR("ViewController::setupFPS(), m_pSelectedVideoFormat == nil.");
        return MAC_S_FALSE;
    }
    NSArray *ranges = m_pSelectedVideoFormat.videoSupportedFrameRateRanges;
    if (ranges == nil || [ranges count] <= 0) {
        MAC_LOG_ERROR("ViewController::setupFPS(), m_pSelectedVideoFormat has no effective AVFrameRageRanges.");
        return MAC_S_FALSE;
    }

    AVFrameRateRange *firstRange = [ranges firstObject];
    m_fMinFPS = [firstRange minFrameRate];
    m_fMaxFPS = [firstRange maxFrameRate];
    for (int i = 1; i < [ranges count]; i++) {
        AVFrameRateRange *range = [ranges objectAtIndex:i];
        if (m_fMaxFPS < [range maxFrameRate]) {
            m_fMaxFPS = [range maxFrameRate];
        }
        if (m_fMaxFPS < [range maxFrameRate]) {
            m_fMaxFPS = [range maxFrameRate];
        }
    }
    NSString *strLabel = [NSString stringWithFormat:@"FPS:%d~%d", (int)m_fMinFPS, (int)m_fMaxFPS];
    [lblFPS setStringValue:strLabel];

    // set default fps;
    m_fSelectedFPS = m_fMaxFPS;

    // set delegate;
    [tfFPS setDelegate:self];

    return MAC_S_OK;
}

- (long)setupButton {
    [btnStart setEnabled:true];
    [btnStart setTitle:@"Start Capture"];

    return MAC_S_OK;
}

- (void)setupAlert {
    m_alert = [[NSAlert alloc] init];
    [m_alert addButtonWithTitle:@"OK"];
    [m_alert setAlertStyle:NSWarningAlertStyle];
}


- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    MAC_LOG_INFO("ViewController::viewDidLoad()");

    if (MAC_S_OK != [self setupCaptureDevice]) {
        return;
    }
    if (MAC_S_OK != [self setupVideoFormat]) {
        return;
    }
    if (MAC_S_OK != [self setupSessionPreset]) {
        return;
    }
    if (MAC_S_OK != [self setupFPS]) {
        return;
    }
    [self setupButton];
    [self setupAlert];

    m_pVideoCapEngine = new CMacAVVideoCapEngine();
}

- (void)dealloc {
    [m_arraySessionPresets dealloc];
    [m_alert dealloc];

    [super dealloc];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)selectVideoFormat:(id)sender {
    NSPopUpButton *btnVideoFormat = sender;
    NSString *strSelectedFormat = [btnVideoFormat titleOfSelectedItem];
    if (m_mapVideoFormat.size() <= 0) {
        MAC_LOG_ERROR("ViewController::selectVideoFormat(), no AVCaptureDeviceFormat available!");
        return;
    }
    std::map<NSString*, AVCaptureDeviceFormat*>::iterator iter = m_mapVideoFormat.find(strSelectedFormat);
    if (iter == m_mapVideoFormat.end()) {
        MAC_LOG_ERROR("ViewController::selectVideoFormat(), the selected video format is invalid!");
        return;
    }
    m_pSelectedVideoFormat = iter->second;
}

- (IBAction)selectSessionPreset:(id)sender {
    NSPopUpButton *btnSessionPreset = sender;
    NSString *strSelectedSessionPreset = [btnSessionPreset titleOfSelectedItem];
    if (m_arraySessionPresets == nil || [m_arraySessionPresets count] <= 0) {
        MAC_LOG_ERROR("ViewController::selectSessionPreset(), no supported session preset available!");
        return;
    }
    if (![m_arraySessionPresets containsObject:strSelectedSessionPreset]) {
        MAC_LOG_ERROR("ViewController::selectSessionPreset(), the selected session preset is invalid!");
        return;
    }
    m_pSelectedSessionPreset = strSelectedSessionPreset;
}

// overwrite NSTextFieldDelegate method;
- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *tfField = [notification object];
    if (tfField != tfFPS) {
        MAC_LOG_ERROR("ViewController::controlTextDidChange(), wrong NSTextField passed in!");
    }
    NSScanner *scanner = [NSScanner scannerWithString:[tfField stringValue]];
    int intValue = -1;
    if (!([scanner scanInt:&intValue] && [scanner isAtEnd])) {
        NSString *warningMessage = [NSString stringWithFormat:@"ERROR: Input is invalid integer!"];
        [m_alert setMessageText:warningMessage];
        [m_alert runModal];
        tfFPS.stringValue = @"";
        tfFPS.placeholderString = [NSString stringWithFormat:@"%d", (int)m_fMaxFPS];
        return;
    }
    if (intValue < m_fMinFPS || intValue > m_fMaxFPS) {
        NSString *warningMessage = [NSString stringWithFormat:@"ERROR: Valid FPS should be %d~%d!",
                                    (int)m_fMinFPS, (int)m_fMaxFPS];
        [m_alert setMessageText:warningMessage];
        [m_alert runModal];
        tfFPS.stringValue = @"";
        tfFPS.placeholderString = [NSString stringWithFormat:@"%d", (int)m_fMaxFPS];
    } else {
        m_fSelectedFPS = intValue;
    }
}

- (long)saveVideoFile {
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:@"Untitle.h264"];
    [panel setMessage:@"Choose the path to save the video file"];
    [panel setAllowsOtherFileTypes:NO];
    [panel setAllowedFileTypes:@[@"h264"]];
    [panel setExtensionHidden:NO];
    [panel setCanCreateDirectories:YES];
    [panel runModal];

    return MAC_S_OK;
}

- (IBAction)buttonClicked:(id)sender {
    NSButton *btn = sender;
    NSString *btnTitle = [btn title];
    if ([btnTitle isEqualToString:@"Start Capture"]) {
        MAC_LOG_INFO("ViewController::buttonClicked(), start capture video.");
        [btn setTitle:@"Stop Capture"];
    } else if ([btnTitle isEqualToString:@"Stop Capture"]) {
        MAC_LOG_INFO("ViewController::buttonClicked(), stop capture video.");
        [self saveVideoFile];
        [btn setTitle:@"Start Capture"];
    }
}

@end
