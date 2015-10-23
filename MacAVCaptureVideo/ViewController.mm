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
@synthesize tfTimer;
@synthesize ivPreviewView;

#pragma mark Init Setup
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
        [itmVideoFormat selectItem:[itmVideoFormat itemWithTitle:defaultStrFormat]];
        [itmVideoFormat setTitle:defaultStrFormat];
        m_pSelectedVideoFormat = defaultFormat;
    } else {
        [itmVideoFormat selectItem:[itmVideoFormat
                                    itemWithTitle:m_mapVideoFormat.begin()->first]];
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
    } else {
        m_pSelectedSessionPreset = [m_arraySessionPresets firstObject];
    }
    [itmSessionPreset selectItem:[itmSessionPreset itemWithTitle:m_pSelectedSessionPreset]];
    [itmSessionPreset setTitle:m_pSelectedSessionPreset];

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
    [tfFPS setFloatValue:m_fSelectedFPS];

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

- (long)setupPreviewLayer {
    AVCaptureSession *captureSession = [m_pVideoCapEngine->getAVVideoCapSession() getAVCaptureSesion];
    [captureSession beginConfiguration];
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    [previewLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
    previewLayer.frame = ivPreviewView.bounds;
    CGRect bounds = ivPreviewView.layer.bounds;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    previewLayer.bounds = bounds;
    previewLayer.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    [ivPreviewView.layer addSublayer:previewLayer];
    [captureSession commitConfiguration];
    
    return MAC_S_OK;
}

- (void)setupSessionFormat {
    m_capSessionFormat.capDevice = m_pVideoCaptureDevice;
    m_capSessionFormat.capFormat = m_pSelectedVideoFormat;
    m_capSessionFormat.capSessionPreset = m_pSelectedSessionPreset;
    m_capSessionFormat.capFPS = m_fSelectedFPS;
}

- (void)timerFireMethod:(NSTimer *)timer {
    if (timer != m_timerRecordCapture) {
        MAC_LOG_ERROR("ViewController::timerFireMethod(), wrong timer.");
        return;
    }
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval duration = currentTime - m_ulStartCaptureTime;
    [tfTimer setFloatValue:duration];
}

- (void)setupTimer {
    NSTimeInterval interval = 0.1;
    m_timerRecordCapture = [NSTimer timerWithTimeInterval:interval
                            target:self selector:@selector(timerFireMethod:)
                            userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:m_timerRecordCapture forMode:NSDefaultRunLoopMode];
    [m_timerRecordCapture setFireDate:[NSDate distantFuture]];  // close timer;
}

- (long)startCapEngine {
    if (!m_pVideoCapEngine->IsRunning()) {
        [self setupSessionFormat];
        long ret = m_pVideoCapEngine->Start(m_capSessionFormat);
        if (ret != MAC_S_OK) {
            MAC_LOG_ERROR("ViewController::startCapEngine(), start VideoCapEngine failed!");
            return MAC_S_FALSE;
        }
    }

    MAC_LOG_INFO("ViewController::startCapEngine(), VideoCapEngine is running now.");

    return MAC_S_OK;
}

#pragma mark viewDidLoad
- (void)viewDidLoad {
    [super viewDidLoad];
    [[self view] setAutoresizingMask:NSViewNotSizable];

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
    [self setupSessionFormat];
    [self setupTimer];
    m_ulStartCaptureTime = [[NSDate date] timeIntervalSince1970];  // just for init;
    [tfTimer setStringValue:@""];
    m_fmFileManager = [NSFileManager defaultManager];

    m_pVideoCapEngine = new CMacAVVideoCapEngine();
    if (NULL == m_pVideoCapEngine) {
        MAC_LOG_ERROR("ViewController::viewDidLoad(), new CMacAVVideoCapEngine failed!");
        return;
    }
    if (MAC_S_OK !=m_pVideoCapEngine->Init(m_capSessionFormat)) {
        MAC_LOG_ERROR("ViewController::viewDidLoad(), CMacAVVideoCapEngine::Init() failed!");
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupPreviewLayer];
    });

    if (MAC_S_OK != [self startCapEngine]) {
        return;
    }
}

- (void)dealloc {
    [m_arraySessionPresets dealloc];
    [m_alert dealloc];
    long ret = m_pVideoCapEngine->Stop();
    if (ret != MAC_S_OK) {
        MAC_LOG_ERROR("ViewController::dealloc(), stop VideoCapEngine failed!");
    }

    [super dealloc];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


#pragma mark UI Response
- (bool)checkEngineStart {
    if (m_pVideoCapEngine->IsCapturing()) {
        NSString *warningMessage = @"WARNING: Couldn't change parameters while capturing video, please stop first.";
        [m_alert setAlertStyle:NSWarningAlertStyle];
        [m_alert setMessageText:warningMessage];
        [m_alert runModal];
        [warningMessage release];
        return MAC_S_FALSE;
    }

    return MAC_S_OK;
}

- (IBAction)selectVideoFormat:(id)sender {
    NSPopUpButton *btnVideoFormat = sender;
    NSString *strSelectedFormat = [btnVideoFormat titleOfSelectedItem];

    NSString *formatName = (NSString *)CMFormatDescriptionGetExtension(
                                [m_pSelectedVideoFormat formatDescription],
                                kCMFormatDescriptionExtension_FormatName);
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(
                                    (CMVideoFormatDescriptionRef)
                                    [m_pSelectedVideoFormat formatDescription]);
    NSString *originVideoFormat = [NSString stringWithFormat:@"%@, %d x %d",
                                   formatName, dimensions.width, dimensions.height];

    if ([strSelectedFormat isEqualToString:originVideoFormat]) {
        return;
    }

    if (MAC_S_OK != [self checkEngineStart]) {
        [btnVideoFormat selectItem:[btnVideoFormat itemWithTitle:originVideoFormat]];
        [btnVideoFormat setTitle:originVideoFormat];
        return;
    }

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
    m_capSessionFormat.capFormat = m_pSelectedVideoFormat;
    
    if (MAC_S_OK != m_pVideoCapEngine->UpdateAVCaptureDeviceFormat(m_pSelectedVideoFormat)) {
        MAC_LOG_ERROR("ViewController::selectVideoFormat(), "
                      << "couldn't update video format in capture engine!");
    }
}

- (IBAction)selectSessionPreset:(id)sender {
    NSPopUpButton *btnSessionPreset = sender;
    NSString *strSelectedSessionPreset = [btnSessionPreset titleOfSelectedItem];

    if ([strSelectedSessionPreset isEqualToString:m_pSelectedSessionPreset]) {
        return;
    }
    if (MAC_S_OK != [self checkEngineStart]) {
        [btnSessionPreset selectItem:[btnSessionPreset itemWithTitle:m_pSelectedSessionPreset]];
        [btnSessionPreset setTitle:m_pSelectedSessionPreset];
        return;
    }

    if (m_arraySessionPresets == nil || [m_arraySessionPresets count] <= 0) {
        MAC_LOG_ERROR("ViewController::selectSessionPreset(), no supported session preset available!");
        return;
    }
    if (![m_arraySessionPresets containsObject:strSelectedSessionPreset]) {
        MAC_LOG_ERROR("ViewController::selectSessionPreset(), the selected session preset is invalid!");
        return;
    }
    m_pSelectedSessionPreset = strSelectedSessionPreset;

    m_capSessionFormat.capSessionPreset = m_pSelectedSessionPreset;
    if (MAC_S_OK != m_pVideoCapEngine->UpdateAVCaptureSessionPreset(m_pSelectedSessionPreset)) {
        MAC_LOG_ERROR("ViewController::selectSessionPreset(), "
                      << "couldn't update session preset in capture engine!");
    }
}

// overwrite NSTextFieldDelegate method;
- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *tfField = [notification object];
    if (tfField != tfFPS) {
        MAC_LOG_ERROR("ViewController::controlTextDidChange(), wrong NSTextField passed in!");
    }
    NSScanner *scanner = [NSScanner scannerWithString:[tfField stringValue]];
    int intValue = -1;
    if (!([scanner scanInt:&intValue] && [scanner isAtEnd])) {
        NSString *warningMessage = [NSString stringWithFormat:@"ERROR: Input is invalid integer!"];
        [m_alert setAlertStyle:NSWarningAlertStyle];
        [m_alert setMessageText:warningMessage];
        [m_alert runModal];
        [warningMessage release];
        [tfFPS setFloatValue:m_fSelectedFPS];
        return;
    }
    if (intValue < m_fMinFPS || intValue > m_fMaxFPS) {
        NSString *warningMessage = [NSString stringWithFormat:@"ERROR: Valid FPS should be %d~%d!",
                                    (int)m_fMinFPS, (int)m_fMaxFPS];
        [m_alert setAlertStyle:NSWarningAlertStyle];
        [m_alert setMessageText:warningMessage];
        [m_alert runModal];
        [warningMessage release];
        [tfFPS setFloatValue:m_fSelectedFPS];
        return;
    }
    
    if ((int)m_fSelectedFPS == intValue) {
        return;
    }
    if (MAC_S_OK != [self checkEngineStart]) {
        [tfField setIntValue:(int)m_fSelectedFPS];
        return;
    }

    m_fSelectedFPS = intValue;
    m_capSessionFormat.capFPS = m_fSelectedFPS;
    if (MAC_S_OK != m_pVideoCapEngine->UpdateAVCaptureSessionFPS(m_fSelectedFPS)) {
        MAC_LOG_ERROR("ViewController::selectFPS(),couldn't update FPS in capture engine!");
    }
}

- (long)startCapture {
    MAC_CHECK_NOTNULL(m_pVideoCapEngine);
    if (!m_pVideoCapEngine->IsRunning()) {
        if (MAC_S_OK != [self startCapEngine]) {
            return MAC_S_FALSE;
        }
    }

    NSString *currentDir = [m_fmFileManager currentDirectoryPath];
    long currentTime = (long)[[NSDate date] timeIntervalSince1970];
    NSString *tmpFile = [NSString stringWithFormat:@"%@/video-%ld.tmp",
                         currentDir, currentTime];
    if (false == [m_fmFileManager createFileAtPath:tmpFile contents:nil attributes:nil]) {
        MAC_LOG_ERROR("ViewController::startCapture(), couldn't create video file");
        return MAC_S_FALSE;
    }

    m_strTmpVideoFile = [tmpFile copy];
    m_pVideoCapEngine->StartCapture(tmpFile);
    m_ulStartCaptureTime = [[NSDate date] timeIntervalSince1970];
    [m_timerRecordCapture setFireDate:[NSDate distantPast]];  // start timer;

    return MAC_S_OK;
}

- (long)saveVideoFile:(unsigned long)totalFrames {
    NSString *formatName = (NSString *)CMFormatDescriptionGetExtension(
                            [m_pSelectedVideoFormat formatDescription],
                            kCMFormatDescriptionExtension_FormatName);
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(
                                    (CMVideoFormatDescriptionRef)[m_pSelectedVideoFormat
                                                                  formatDescription]);
    NSString *format = nil;
    if ([formatName isEqualToString:@"Y'CbCr 4:2:2 - yuvs"]) {
        format = @"yuvs";
    } else if ([formatName isEqualToString:@"Y'CbCr 4:2:2 - uyuv"]) {
        format = @"uyuv";
    } else if ([formatName isEqualToString:@"Y'CbCr 4:2:0 - 420v"]) {
        format = @"420v";
    } else {
        format = @"unknown";
    }
    NSString *prefix = [NSString stringWithFormat:@"%d*%d_%dFPS_%@",
                        dimensions.width, dimensions.height, (int)m_fSelectedFPS, format];
    NSString *suffix = @"yuv";

    NSString *defaultFileName = [NSString stringWithFormat:@"%@.%@", prefix, suffix];
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:defaultFileName];
    [panel setMessage:@"Choose the path to save the video file"];
    [panel setAllowedFileTypes:[NSArray arrayWithObject:suffix]];
    [panel setAllowsOtherFileTypes:NO];
    [panel setExtensionHidden:NO];
    [panel setCanCreateDirectories:YES];

    NSInteger result = [panel runModal];
    NSError *error = nil;
    if (result == NSModalResponseOK) {
        NSString *saveFilePath = [[panel URL] path];
        if ([m_fmFileManager fileExistsAtPath:saveFilePath]) {
            if (false == [m_fmFileManager removeItemAtPath:saveFilePath error:&error]) {
                NSString *errorString = [[NSString alloc] initWithFormat:@"%@", error];
                MAC_LOG_ERROR("ViewController::saveVideoFile():" << [errorString UTF8String]);
                [errorString release];
                return MAC_S_FALSE;
            }
        }
        if (false == [m_fmFileManager moveItemAtPath:m_strTmpVideoFile toPath:saveFilePath error:&error]) {
            NSString *errorString = [[NSString alloc] initWithFormat:@"%@", error];
            MAC_LOG_ERROR("ViewController::saveVideoFile():" << [errorString UTF8String]);
            [errorString release];
            return MAC_S_FALSE;
        } else {
            NSString *infoMessage = [NSString stringWithFormat:@"Video File Saved To: %@ with %ld frames",
                                     saveFilePath, totalFrames];
            [m_alert setAlertStyle:NSInformationalAlertStyle];
            [m_alert setMessageText:infoMessage];
            [m_alert runModal];
            [infoMessage release];
        }
    } else {
        return MAC_S_OK;
    }

    return MAC_S_OK;
}

- (long)stopCapture {
    unsigned long totalFrames;
    m_pVideoCapEngine->StopCapture(totalFrames);
    [self saveVideoFile:totalFrames];
    [m_timerRecordCapture setFireDate:[NSDate distantFuture]];  // close timer;
    [tfTimer setStringValue:@""];

    return MAC_S_OK;
}

- (IBAction)buttonClicked:(id)sender {
    NSButton *btn = sender;
    NSString *btnTitle = [btn title];
    if ([btnTitle isEqualToString:@"Start Capture"]) {
        MAC_LOG_INFO("ViewController::buttonClicked(), start capture video.");
        [self startCapture];
        [btn setTitle:@"Stop Capture"];
    } else if ([btnTitle isEqualToString:@"Stop Capture"]) {
        MAC_LOG_INFO("ViewController::buttonClicked(), stop capture video.");
        // [self saveVideoFile];
        [self stopCapture];
        [btn setTitle:@"Start Capture"];
    }
}

@end
