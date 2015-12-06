//  MacVideoCapEngine.m
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVCaptureSession.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSString.h>
#import <CoreVideo/CVPixelBuffer.h>

#import "MacVideoCapEngine.h"
#import "MacLog.h"

#pragma mark CMacAVVideoCapEngine
CMacAVVideoCapEngine::CMacAVVideoCapEngine() : m_pVideoCapSession(NULL), m_bStartCapture(false),
                                               m_captureFile(nil), m_fileHandle(nil),
                                               m_metaFile(nil), m_metaHandle(nil), m_ulCounter(0)
{
    memset(&m_capSessionFormat , 0, sizeof(m_capSessionFormat));
    m_fileLock = [[NSLock alloc] init];
}

CMacAVVideoCapEngine::~CMacAVVideoCapEngine()
{
}

long CMacAVVideoCapEngine::Init(MACCaptureSessionFormat &capSessioinFormat)
{
    m_capSessionFormat = capSessioinFormat;

    if (nil == m_pVideoCapSession) {
        m_pVideoCapSession = [[CMacAVVideoCapSession alloc] init];
    }
    if (nil == m_pVideoCapSession) {
        MAC_LOG_ERROR("MacVideoCapSession::init(), couldn't init AVCaptureSession.");
        return MAC_S_FALSE;
    }

    [m_pVideoCapSession setSink:this];
    [m_pVideoCapSession setCapSessionFormat:m_capSessionFormat];

    return MAC_S_OK;
}

void CMacAVVideoCapEngine::Uninit()
{
    [m_pVideoCapSession setSink:NULL];
    [m_pVideoCapSession release];
    m_pVideoCapSession = NULL;
}

CMacAVVideoCapSession *CMacAVVideoCapEngine::getAVVideoCapSession()
{
    return m_pVideoCapSession;
}

long CMacAVVideoCapEngine::Start(MACCaptureSessionFormat &capSessionFormat)
{
    if (YES == [m_pVideoCapSession isRunning]) {
        MAC_LOG_ERROR("CMacAVVideoCapEngine::Start(), AVCaptureSession is already running.");
        return MAC_S_FALSE;
    }

    m_capSessionFormat = capSessionFormat;
    if ([m_pVideoCapSession startRun:m_capSessionFormat] != MAC_S_OK) {
        MAC_LOG_ERROR("CMacAVVideoCapEngine::Start(), AVCaptureSession start failed!");
        return MAC_S_FALSE;
    }

    return MAC_S_OK;
}

bool CMacAVVideoCapEngine::IsRunning()
{
    return [m_pVideoCapSession isRunning];
}

long CMacAVVideoCapEngine::Stop()
{
    return [m_pVideoCapSession stopRun];
}

long CMacAVVideoCapEngine::StartCapture(NSString *strCaptureFile, NSString *strMetaFile)
{
    m_bStartCapture = true;
    m_captureFile = [strCaptureFile copy];
    m_fileHandle = [[NSFileHandle fileHandleForWritingAtPath:m_captureFile] retain];
    m_metaFile = [strMetaFile copy];
    m_metaHandle = [[NSFileHandle fileHandleForWritingAtPath:m_metaFile] retain];
    m_ulCounter = 0;

    return MAC_S_OK;
}

long CMacAVVideoCapEngine::StopCapture(unsigned long &totalFrames)
{
    m_bStartCapture = false;
    [m_fileLock lock];
    [m_fileHandle closeFile];
    m_fileHandle = nil;
    [m_metaHandle closeFile];
    m_metaHandle = nil;
    totalFrames = m_ulCounter;
    m_ulCounter = 0;
    [m_fileLock unlock];

    return MAC_S_OK;
}

bool CMacAVVideoCapEngine::IsCapturing() {
    return m_bStartCapture;
}

long CMacAVVideoCapEngine::UpdateAVCaptureDeviceFormat(AVCaptureDeviceFormat *format)
{
    m_capSessionFormat.capFormat = format;
    return [m_pVideoCapSession updateAVCaptureDeviceFormat:format];
}
long CMacAVVideoCapEngine::UpdateAVCaptureSessionPreset(NSString *preset)
{
    m_capSessionFormat.capSessionPreset = preset;
    return [m_pVideoCapSession updateAVCaptureSessionPreset:preset];
}
long CMacAVVideoCapEngine::UpdateAVCaptureSessionFPS(float fps)
{
    m_capSessionFormat.capFPS = fps;
    return [m_pVideoCapSession updateAVCaptureSessionFPS:fps];
}

long CMacAVVideoCapEngine::DeliverVideoData(VideoRawDataPack* pVideoPack)
{
    if (m_bStartCapture && m_fileHandle) {
        if (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange == pVideoPack->fmtVideoFormat.video_type) {
            [m_fileLock lock];
            for (int i = 0; i < pVideoPack->ulPlaneCount; i++) {
                NSData *data = [NSData dataWithBytes:pVideoPack->pSrcData[i]
                                              length:pVideoPack->ulSrcDatalen[i]];
                [m_fileHandle seekToEndOfFile];
                [m_fileHandle writeData:data];
            }
            m_ulCounter++;

            NSString *metaLine = [NSString stringWithFormat:@"FrameIdx:%lu timestamp:%lld:%d Resolution:%ld * %ld\n",
                                 m_ulCounter, pVideoPack->pts.value, pVideoPack->pts.timescale,
                                 pVideoPack->fmtVideoFormat.width, pVideoPack->fmtVideoFormat.height];
            NSData *metaData = [metaLine dataUsingEncoding:NSUTF8StringEncoding];
            [m_metaHandle seekToEndOfFile];
            [m_metaHandle writeData:metaData];

            [m_fileLock unlock];
        } else if (kCVPixelFormatType_422YpCbCr8_yuvs == pVideoPack->fmtVideoFormat.video_type) {
            [m_fileLock lock];
            NSData *data = [NSData dataWithBytes:pVideoPack->pSrcData[0]
                                          length:pVideoPack->ulDataLen];
            [m_fileHandle seekToEndOfFile];
            [m_fileHandle writeData:data];
            m_ulCounter++;

            NSString *metaLine = [NSString stringWithFormat:@"FrameIdx:%lu timestamp:%lld:%d Resolution:%ld * %ld\n",
                                 m_ulCounter, pVideoPack->pts.value, pVideoPack->pts.timescale,
                                 pVideoPack->fmtVideoFormat.width, pVideoPack->fmtVideoFormat.height];
            NSData *metaData = [metaLine dataUsingEncoding:NSUTF8StringEncoding];
            [m_metaHandle seekToEndOfFile];
            [m_metaHandle writeData:metaData];

            [m_fileLock unlock];
        } else if (kCVPixelFormatType_422YpCbCr8 == pVideoPack->fmtVideoFormat.video_type) {
            [m_fileLock lock];
            NSData *data = [NSData dataWithBytes:pVideoPack->pSrcData[0]
                                          length:pVideoPack->ulDataLen];
            [m_fileHandle seekToEndOfFile];
            [m_fileHandle writeData:data];
            m_ulCounter++;

            NSString *metaLine = [NSString stringWithFormat:@"FrameIdx:%lu timestamp:%lld:%d Resolution:%ld * %ld\n",
                                 m_ulCounter, pVideoPack->pts.value, pVideoPack->pts.timescale,
                                 pVideoPack->fmtVideoFormat.width, pVideoPack->fmtVideoFormat.height];
            NSData *metaData = [metaLine dataUsingEncoding:NSUTF8StringEncoding];
            [m_metaHandle seekToEndOfFile];
            [m_metaHandle writeData:metaData];

            [m_fileLock unlock];
        }
    }

    return MAC_S_OK;
}

long CMacAVVideoCapEngine::DeliverVideoData(CMSampleBufferRef sampleBuffer)
{
    if (!m_bStartCapture) {
        return MAC_S_OK;
    }

    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    VideoRawDataPack packet = { 0 };
    packet.pts = pts;
    if (kCVReturnSuccess == CVPixelBufferLockBaseAddress(imageBuffer, 0)) {
        if (0 == CVImageBuffer2VideoRawPacket(imageBuffer, packet)) {
            DeliverVideoData(&packet);
        }
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    }

    return MAC_S_OK;
}

int CVImageBuffer2VideoRawPacket(CVImageBufferRef imageBuffer, VideoRawDataPack& packet)
{
    packet.ulRotation = 0;
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    packet.fmtVideoFormat.video_type = MAC420v;
    packet.fmtVideoFormat.width = CVPixelBufferGetWidth(imageBuffer);
    packet.fmtVideoFormat.height = CVPixelBufferGetHeight(imageBuffer);
    packet.fmtVideoFormat.frame_rate = 0;
    packet.fmtVideoFormat.time_stamp = [[NSDate date] timeIntervalSince1970];
    packet.ulPlaneCount = CVPixelBufferGetPlaneCount(imageBuffer);
    if (kCVPixelFormatType_422YpCbCr8_yuvs == pixelFormat) {
        packet.fmtVideoFormat.video_type = Macyuyv;
        packet.pSrcData[0] = (unsigned char *)CVPixelBufferGetBaseAddress(imageBuffer);
        packet.ulDataLen = CVPixelBufferGetBytesPerRow(imageBuffer) * packet.fmtVideoFormat.height;
    } else if (kCVPixelFormatType_422YpCbCr8 == pixelFormat) {
        packet.fmtVideoFormat.video_type = Macuyvy;
        packet.pSrcData[0] = (unsigned char *)CVPixelBufferGetBaseAddress(imageBuffer);
        packet.ulDataLen = CVPixelBufferGetBytesPerRow(imageBuffer) * packet.fmtVideoFormat.height;
    } else if (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange == pixelFormat) {  // NV12 actually;
        packet.fmtVideoFormat.video_type = MAC420v;
        for (int i = 0; i < packet.ulPlaneCount; i++) {
            packet.pSrcData[i] = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i);
            packet.ulSrcStride[i] = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, i);
            packet.ulSrcDatalen[i] = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, i)
                                    * CVPixelBufferGetHeightOfPlane(imageBuffer, i);
            packet.ulDataLen += packet.ulSrcDatalen[i];
        }
    } else {
        packet.fmtVideoFormat.video_type = MacUnknown;
    }
    
    return MAC_S_OK;
}
