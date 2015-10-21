//
//  MacVideoCapSession.m
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#import <AVFoundation/AVCaptureSession.h>
#import <AVFoundation/AVFoundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSString.h>

#import "MacVideoCapSession.h"
#import "MacLog.h"

static void capture_cleanup(void* p)
{
    CMacAVVideoCapSession* captureSession = (__bridge CMacAVVideoCapSession *)p;
    [captureSession captureCleanup];
}

#pragma mark CMacAVVideoCapSession

@implementation CMacAVVideoCapSession

- (id)init
{
    m_captureSession = nil;
    m_videoCaptureDevice = nil;
    m_videoCaptureInput = nil;
    m_videoCaptureDataOutput = nil;
    m_videoOrientation = AVCaptureVideoOrientationPortrait;
    memset(&m_format, sizeof(m_format), 0);
    m_sink = NULL;
    m_sinkLock = [[NSRecursiveLock alloc] init];
    
    self = [super init];
    if (nil != self) {
        m_captureSession = [[AVCaptureSession alloc] init];
        if (nil == m_captureSession) {
            MAC_LOG_ERROR("MacVideoCapSession::init(), couldn't init AVCaptureSession.");
            return nil;
        }
    } else {
        MAC_LOG_ERROR("MacVideoCapSession::init(), super init failed.");
        return nil;
    }

    return self;
}

- (AVCaptureSession *)getAVCaptureSesion
{
    return m_captureSession;
}

- (long)setCapSessionFormat:(MACCaptureSessionFormat&)format
{
    m_videoCaptureDevice = format.capDevice;
    [m_videoCaptureDevice retain];
    m_format.capDevice = format.capDevice;
    m_format.capFormat = format.capFormat;
    m_format.capSessionPreset = format.capSessionPreset;
    m_format.capFPS = format.capFPS;

    return MAC_S_OK;
}

- (long)getCapSessionFormat:(MACCaptureSessionFormat&)format
{
    format.capDevice = m_videoCaptureDevice;
    format.capDevice = m_format.capDevice;
    format.capFormat = m_format.capFormat;
    format.capSessionPreset = m_format.capSessionPreset;
    format.capFPS = m_format.capFPS;

    return MAC_S_OK;
}

- (void)dealloc
{
    m_sink = NULL;
    [m_sinkLock release];
    m_sinkLock = NULL;
    
    [m_captureSession removeInput:m_videoCaptureInput];
    [m_captureSession removeOutput:m_videoCaptureDataOutput];
    
    [m_videoCaptureInput release];
    [m_videoCaptureDataOutput release];
    [m_videoCaptureDevice release];
    [m_captureSession release];
    
    [super dealloc];
}

- (void)setSink:(IMacAVVideoCapSessionSink*)sink
{
    [m_sinkLock lock];
    m_sink = sink;
    [m_sinkLock unlock];
}

- (int)createVideoInputAndOutput
{
    if(NULL == m_captureSession) {
        return MAC_E_POINTER;
    }
    
    int result = MAC_S_OK;
    [m_captureSession beginConfiguration];
    do {
        NSError *error = NULL;
        
        if (NULL != m_videoCaptureInput) {
            [m_captureSession removeInput:m_videoCaptureInput];
            [m_videoCaptureInput release];
        }
        
        m_videoCaptureInput =
        [[NSClassFromString(@"AVCaptureDeviceInput") alloc] initWithDevice:m_videoCaptureDevice error:&error];
        if (NULL != m_videoCaptureInput) {
            [m_captureSession addInput:m_videoCaptureInput];
        } else {
            NSString *errorString = [[NSString alloc] initWithFormat:@"%@", error];
            [errorString release];
            result = MAC_E_POINTER;
            break;
        }
        
        if (NULL == m_videoCaptureDataOutput) {
            m_videoCaptureDataOutput = [[NSClassFromString(@"AVCaptureVideoDataOutput") alloc] init];
            if (NULL != m_videoCaptureDataOutput) {
                dispatch_queue_t macAVCaptureQueue = dispatch_queue_create("MacAVCaptureQueue", NULL);
                dispatch_set_context(macAVCaptureQueue, [self retain]);
                dispatch_set_finalizer_f(macAVCaptureQueue, capture_cleanup);
                
                [m_videoCaptureDataOutput setSampleBufferDelegate:self queue:macAVCaptureQueue];
                dispatch_release(macAVCaptureQueue);
                [m_captureSession addOutput:m_videoCaptureDataOutput];
            } else {
                break;
            }
        }
        
        NSArray *connections = [m_videoCaptureDataOutput connections];
        NSUInteger connectionCount = [connections count];
        if (connectionCount > 0) {
            id connection = [connections objectAtIndex:0];
            
            // get orientation
            m_videoOrientation = [connection videoOrientation];
        }
    } while(0);
    
    [m_captureSession commitConfiguration];
    
    return result;
}

- (int)destroyVideoInputAndOutput
{
    [m_captureSession beginConfiguration];
    
    [m_captureSession removeInput:m_videoCaptureInput];
    [m_videoCaptureInput release];
    m_videoCaptureInput = nil;
    
    [m_captureSession removeOutput:m_videoCaptureDataOutput];
    [m_videoCaptureDataOutput setSampleBufferDelegate:NULL queue:NULL];
    [m_videoCaptureDataOutput release];
    m_videoCaptureDataOutput = NULL;
    
    [m_captureSession commitConfiguration];
    
    return MAC_S_OK;
}

- (BOOL)isRunning
{
    return [m_captureSession isRunning];
}

- (long)startRun
{
    if (YES == [m_captureSession isRunning]) {
        return MAC_S_FALSE;
    }
    
    int result = [self createVideoInputAndOutput];
    if(MAC_S_OK == result) {
        [self updateVideoFormat];
    } else {
        return result;
    }
    
    [m_captureSession startRunning];
    if (NO == [m_captureSession isRunning]) {
        [self destroyVideoInputAndOutput];
        return MAC_S_FALSE;
    }
    
    return MAC_S_OK;
}

- (long)stopRun
{
    if (NO == [m_captureSession isRunning]) {
        return MAC_S_FALSE;
    }

    [m_captureSession stopRunning];
    [self destroyVideoInputAndOutput];
    if (YES == [m_captureSession isRunning]) {
        return MAC_E_FAIL;
    }
    
    return MAC_S_OK;
}

- (void)captureCleanup
{
    [self release];
}

- (long)updateVideoFormat
{
#if 0
    if (MacYUY2 != m_videoFormat.video_type
        && MacARGB32 != m_videoFormat.video_type
        && MacBGRA32 != m_videoFormat.video_type) {
        return MAC_E_INVALIDARG;
    }
    
    if (m_videoFormat.width <= 0
        || m_videoFormat.height <= 0
        || m_videoFormat.frame_rate <= 0) {
        return MAC_E_INVALIDARG;
    }
    
    if (NULL == m_captureSession
        || NULL == m_videoCaptureDataOutput) {
        return MAC_E_POINTER;
    }
    
    [m_captureSession beginConfiguration];
    
    // set max frame rate
    NSArray *connections = [m_videoCaptureDataOutput connections];
    NSUInteger connectionCount = [connections count];
    if (connectionCount > 0) {
        id connection = [connections objectAtIndex:0];
        if (YES == [connection isVideoMinFrameDurationSupported]) {
            [connection setVideoMinFrameDuration: CMTimeMakeWithSeconds(1.0 / m_videoFormat.frame_rate, 10000)];
        }
    }
    
    NSString *sessionPreset = AVCaptureSessionPreset640x480;
    if (m_videoFormat.width <= 320 && m_videoFormat.height <= 240) {
        sessionPreset = AVCaptureSessionPreset320x240;
    } else if (m_videoFormat.width <= 352 && m_videoFormat.height <= 288) {
        sessionPreset = AVCaptureSessionPreset352x288;
    } else if (m_videoFormat.width <= 640 && m_videoFormat.height <= 480) {
        sessionPreset = AVCaptureSessionPreset640x480;
    } else if (m_videoFormat.width <= 960 && m_videoFormat.height <= 540) {
        sessionPreset = AVCaptureSessionPreset960x540;
    } else if (m_videoFormat.width <= 1280 && m_videoFormat.height <= 720) {
        sessionPreset = AVCaptureSessionPreset1280x720;
    } else {
        sessionPreset = AVCaptureSessionPresetHigh;
    }
    [m_captureSession setSessionPreset: sessionPreset];
    
    // set video type
    unsigned int pixelFormat = kCVPixelFormatType_422YpCbCr8_yuvs;
    if (MacYUY2 == m_videoFormat.video_type) {
        pixelFormat = kCVPixelFormatType_422YpCbCr8_yuvs;
    } else if (MacARGB32 == m_videoFormat.video_type) {
        pixelFormat = kCVPixelFormatType_32ARGB;
    } else if (MacBGRA32 == m_videoFormat.video_type) {
        pixelFormat = kCVPixelFormatType_32BGRA;
    }
    
    [m_videoCaptureDataOutput setVideoSettings:nil];
    NSMutableDictionary* videoSettings = [NSMutableDictionary dictionaryWithCapacity:0];
    [videoSettings addEntriesFromDictionary:[m_videoCaptureDataOutput videoSettings]];
    [videoSettings setObject:[NSNumber numberWithUnsignedInt:pixelFormat]
                      forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
    [videoSettings setObject:AVVideoScalingModeResizeAspectFill forKey:AVVideoScalingModeKey];
    [m_videoCaptureDataOutput setVideoSettings:videoSettings];
    
    [m_captureSession commitConfiguration];
#endif
    
    return MAC_S_OK;
}

#if 0
- (int)setVideoFormat:(MacVideoFormat&)format;
{
    m_videoFormat = format;
    
    if (MAC_S_OK != [self updateVideoFormat]) {
        return MAC_E_FAIL;
    }
    
    return MAC_S_OK;
}

- (int)getVideoFormat:(MacVideoFormat&)format
{
    format = m_videoFormat;
    
    if (NULL == m_captureSession || NULL == m_videoCaptureDataOutput) {
        return MAC_E_POINTER;
    }
    
    // get max frame rate
    NSArray *connections = [m_videoCaptureDataOutput connections];
    NSUInteger connectionCount = [connections count];
    if (connectionCount > 0) {
        id connection = [connections objectAtIndex:0];
        if (YES == [connection isVideoMinFrameDurationSupported]) {
            CMTime minFrameDuration = [connection videoMinFrameDuration];
            format.frame_rate =
            (minFrameDuration.value > 0) ? (minFrameDuration.timescale / minFrameDuration.value) : 0;
        }
    }
    
    // get video type
    NSDictionary *videoSettings = [m_videoCaptureDataOutput videoSettings];
    unsigned int pixelFormat = [[videoSettings objectForKey:
                                 (NSString*)kCVPixelBufferPixelFormatTypeKey] unsignedIntValue];
    if (kCVPixelFormatType_422YpCbCr8 == pixelFormat) {
        format.video_type = MacUnknown;
    } else if (kCVPixelFormatType_422YpCbCr8_yuvs == pixelFormat) {
        format.video_type = MacYUY2;
    } else if (kCVPixelFormatType_32ARGB == pixelFormat) {
        format.video_type = MacARGB32;
    } else if (kCVPixelFormatType_32BGRA == pixelFormat) {
        format.video_type = MacBGRA32;
    } else {
        format.video_type = MacUnknown;
    }
    
    // get video size
    NSString *sessionPreset = [m_captureSession sessionPreset];
    if (NSOrderedSame == [sessionPreset compare:AVCaptureSessionPreset320x240]) {
        format.width = 320;
        format.height = 240;
    } else if (NSOrderedSame == [sessionPreset compare:AVCaptureSessionPreset352x288]) {
        format.width = 352;
        format.height = 288;
    } else if (NSOrderedSame == [sessionPreset compare:AVCaptureSessionPreset640x480]) {
        format.width = 640;
        format.height = 480;
    } else if (NSOrderedSame == [sessionPreset compare:AVCaptureSessionPreset960x540]) {
        format.width = 960;
        format.height = 540;
    } else if (NSOrderedSame == [sessionPreset compare:AVCaptureSessionPreset1280x720]) {
        format.width = 1280;
        format.height = 720;
    } else if (NSOrderedSame == [sessionPreset compare:AVCaptureSessionPresetHigh]
               || NSOrderedSame == [sessionPreset compare:AVCaptureSessionPresetLow]
               || NSOrderedSame == [sessionPreset compare:AVCaptureSessionPresetMedium]) {
        format.width = 0;
        format.height = 0;
    }
    
    return MAC_S_OK;
}
#endif


// Notes: the call back function will be called from capture thread.
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if(NO == [m_captureSession isRunning]) {
        return;
    }
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if (m_sink ) {
        m_sink->DeliverVideoData(imageBuffer);
    }
}

@end

