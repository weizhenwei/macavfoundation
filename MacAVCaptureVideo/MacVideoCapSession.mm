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
    m_format = format;
    m_videoCaptureDevice = format.capDevice;

    return MAC_S_OK;
}

- (long)getCapSessionFormat:(MACCaptureSessionFormat&)format
{
    format = m_format;

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

- (long)createVideoInputAndOutput
{
    if (nil == m_captureSession) {
        MAC_LOG_ERROR("CMacAVVideoCapSession::createVideoInputAndOutput(), AVCaptureSession is nil.");
        return MAC_S_FALSE;
    }
    
    long result = MAC_S_OK;
    [m_captureSession beginConfiguration];
    do {
        NSError *error = nil;

        if (nil != m_videoCaptureInput) {
            [m_captureSession removeInput:m_videoCaptureInput];
            [m_videoCaptureInput release];
        }

        m_videoCaptureInput =
        [[AVCaptureDeviceInput alloc] initWithDevice:m_format.capDevice error:&error];
        if (nil != m_videoCaptureInput) {
            [m_captureSession addInput:m_videoCaptureInput];
        } else {
            NSString *errorString = [[NSString alloc] initWithFormat:@"%@", error];
            MAC_LOG_ERROR("CMacAVVideoCapSession::createVideoInputAndOutput():" << [errorString UTF8String]);
            [errorString release];
            result = MAC_S_FALSE;
            break;
        }

        if (nil == m_videoCaptureDataOutput) {
            m_videoCaptureDataOutput = [[AVCaptureVideoDataOutput alloc] init];
            if (nil != m_videoCaptureDataOutput) {
                dispatch_queue_t macAVCaptureQueue = dispatch_queue_create("MacAVCaptureQueue", nil);
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

- (long)startRun:(MACCaptureSessionFormat&)format
{
    m_format = format;
    if (nil == m_captureSession) {
        MAC_LOG_ERROR("CMacAVVideoCapSession::startRun(), AVCaptureSession is nil.");
        return MAC_S_FALSE;
    }
    if (YES == [m_captureSession isRunning]) {
        MAC_LOG_ERROR("CMacAVVideoCapSession::startRun(), AVCaptureSession is already running.");
        return MAC_S_FALSE;
    }

    long result = [self createVideoInputAndOutput];
    if (MAC_S_OK != result) {
        return result;
    }
    result = [self updateVideoFormat];
    if (MAC_S_OK != result) {
        return result;
    }
    
    [m_captureSession startRunning];
    if (NO == [m_captureSession isRunning]) {
        [self destroyVideoInputAndOutput];
        MAC_LOG_ERROR("CMacAVVideoCapSession::startRun(), AVCaptureSession couldn't start running.");
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
        MAC_LOG_ERROR("CMacAVVideoCapSession::stopRun(), AVCaptureSession couldn't stop running.");
        return MAC_S_FALSE;
    }

    return MAC_S_OK;
}

- (void)captureCleanup
{
    [self release];
}

- (long)updateAVCaptureDeviceFormat:(AVCaptureDeviceFormat *)format {
    m_format.capFormat = format;

    [m_captureSession commitConfiguration];
    NSError *error = nil;
    if ([m_videoCaptureDevice lockForConfiguration:&error]) {
        [m_videoCaptureDevice setActiveFormat:m_format.capFormat];
        [m_videoCaptureDevice unlockForConfiguration];
    } else {
        NSString *errorString = [[NSString alloc] initWithFormat:@"%@", error];
        MAC_LOG_ERROR("CMacAVVideoCapSession::updateAVCaptureDeviceFormat():" << [errorString UTF8String]);
        [errorString release];
        return MAC_S_FALSE;
    }

    MacVideoOutputFormat videoOutputFormat = [self getVideoOutputFormat];
    [m_videoCaptureDataOutput setVideoSettings:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithInt: videoOutputFormat.video_type],
                                                kCVPixelBufferPixelFormatTypeKey,
                                                [NSNumber numberWithInt: videoOutputFormat.width],
                                                (id)kCVPixelBufferWidthKey,
                                                [NSNumber numberWithInt: videoOutputFormat.height],
                                                (id)kCVPixelBufferHeightKey,
                                                AVVideoScalingModeFit,
                                                (id)AVVideoScalingModeKey,
                                                nil]];

    [m_captureSession commitConfiguration];

    return MAC_S_OK;
}
- (long)updateAVCaptureSessionPreset:(NSString *)preset {
    m_format.capSessionPreset = preset;
    [m_captureSession beginConfiguration];
    [m_captureSession setSessionPreset: m_format.capSessionPreset];
    [m_captureSession commitConfiguration];

    return MAC_S_OK;
}
- (long)updateAVCaptureSessionFPS:(float)fps {
    m_format.capFPS = fps;
    [m_captureSession beginConfiguration];
    NSArray *connections = [m_videoCaptureDataOutput connections];
    NSUInteger connectionCount = [connections count];
    if (connectionCount > 0) {
        id connection = [connections objectAtIndex:0];
        if (YES == [connection isVideoMinFrameDurationSupported]) {
            [connection setVideoMinFrameDuration: CMTimeMakeWithSeconds(1.0 / m_format.capFPS, 10000)];
        }
    }
    [m_captureSession commitConfiguration];

    return MAC_S_OK;
}


// Y'CbCr 4:2:2 - yuvs: kCVPixelFormatType_422YpCbCr8_yuvs
// Y'CbCr 4:2:2 - uyuv: kCVPixelFormatType_422YpCbCr8
// Y'CbCr 4:2:0 - 420v: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
- (MacVideoOutputFormat)getVideoOutputFormat
{
    MacVideoOutputFormat videoOutputFormat;
    NSString *formatName = (NSString *)CMFormatDescriptionGetExtension(
                            [m_format.capFormat formatDescription],
                            kCMFormatDescriptionExtension_FormatName);
    if ([formatName isEqualToString:@"Y'CbCr 4:2:2 - yuvs"]) {
        videoOutputFormat.video_type = (MacVideoType)kCVPixelFormatType_422YpCbCr8_yuvs;
    } else if ([formatName isEqualToString:@"Y'CbCr 4:2:2 - uyuv"]) {
        videoOutputFormat.video_type = (MacVideoType)kCVPixelFormatType_422YpCbCr8;
    } else if ([formatName isEqualToString:@"Y'CbCr 4:2:0 - 420v"]) {
        videoOutputFormat.video_type = (MacVideoType)kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    } else {
        videoOutputFormat.video_type = MacUnknown;
    }

    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(
                                    (CMVideoFormatDescriptionRef)[m_format.capFormat formatDescription]);
    videoOutputFormat.width = dimensions.width;
    videoOutputFormat.height = dimensions.height;

    [formatName release];
    return videoOutputFormat;
}

- (long)updateVideoFormat
{
    if (nil == m_captureSession
        || nil == m_videoCaptureDataOutput) {
        MAC_LOG_ERROR("CMacAVVideoCapSession::updateVideoFormat(), "
                      << "m_captureSession == nil || m_videoCaptureDataOutput == nil.");
    }

    [m_captureSession beginConfiguration];
    
    // set max frame rate
    NSArray *connections = [m_videoCaptureDataOutput connections];
    NSUInteger connectionCount = [connections count];
    if (connectionCount > 0) {
        id connection = [connections objectAtIndex:0];
        if (YES == [connection isVideoMinFrameDurationSupported]) {
            [connection setVideoMinFrameDuration: CMTimeMakeWithSeconds(1.0 / m_format.capFPS, 10000)];
        }
    }
    [m_captureSession setSessionPreset: m_format.capSessionPreset];
    
    NSError *error = nil;
    if ([m_videoCaptureDevice lockForConfiguration:&error]) {
        [m_videoCaptureDevice setActiveFormat:m_format.capFormat];
        [m_videoCaptureDevice unlockForConfiguration];
    } else {
        NSString *errorString = [[NSString alloc] initWithFormat:@"%@", error];
        MAC_LOG_ERROR("CMacAVVideoCapSession::updateVideoFormat():" << [errorString UTF8String]);
        [errorString release];
        return MAC_S_FALSE;
    }

    MacVideoOutputFormat videoOutputFormat = [self getVideoOutputFormat];
    [m_videoCaptureDataOutput setVideoSettings:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithInt: videoOutputFormat.video_type],
                                                kCVPixelBufferPixelFormatTypeKey,
                                                [NSNumber numberWithInt: videoOutputFormat.width],
                                                (id)kCVPixelBufferWidthKey,
                                                [NSNumber numberWithInt: videoOutputFormat.height],
                                                (id)kCVPixelBufferHeightKey,
                                                AVVideoScalingModeFit,
                                                (id)AVVideoScalingModeKey,
                                                nil]];

    [m_captureSession commitConfiguration];

    return MAC_S_OK;
}

#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
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

