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

CMacAVVideoCapEngine::CMacAVVideoCapEngine() : m_pVideoCapSession(NULL)
{
    memset(&m_capSessionFormat , 0, sizeof(m_capSessionFormat));
}

CMacAVVideoCapEngine::~CMacAVVideoCapEngine()
{
    Uninit();
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
    Stop();

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

long CMacAVVideoCapEngine::Stop()
{
    return [m_pVideoCapSession stopRun];
}


int CMacAVVideoCapEngine::DeliverVideoData(VideoRawDataPack* pVideoPack)
{
    // TODO: save video data to video file;
    return MAC_S_OK;
}

int CMacAVVideoCapEngine::DeliverVideoData(CVImageBufferRef imageBuffer)
{
    VideoRawDataPack packet = { 0 };
    
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
    packet.uiRotation = 0;
    {
        OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
        size_t pixelWidth = CVPixelBufferGetWidth(imageBuffer);
        size_t pixelHeight = CVPixelBufferGetHeight(imageBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        void* baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        size_t dataSize = bytesPerRow * pixelHeight;
        Boolean isPlanar = CVPixelBufferIsPlanar(imageBuffer);
        size_t planeCount = CVPixelBufferGetPlaneCount(imageBuffer);
        size_t planeSize[MAX_PLANE_COUNT];
        if (true == isPlanar && planeCount > 0) {
            if (planeCount <= MAX_PLANE_COUNT) {
                baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
                dataSize = 0;
                size_t planeWidth = 0, planeHeight = 0, planeBytesPreRow = 0;
                for (int i = 0; i < planeCount; i++) {
                    planeWidth = CVPixelBufferGetWidthOfPlane(imageBuffer, i);
                    planeHeight = CVPixelBufferGetHeightOfPlane(imageBuffer, i);
                    planeBytesPreRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, i);
                    planeSize[i] = planeBytesPreRow * planeHeight;
                    dataSize += planeBytesPreRow * planeHeight;
                }
            } else {
                return -1;
            }
        }
        unsigned int uTimeStamp = static_cast<unsigned int>(time(NULL)/1000);
        packet.fmtVideoFormat = {MacUnknown, pixelWidth, pixelHeight, 0, uTimeStamp};
        if (kCVPixelFormatType_422YpCbCr8 == pixelFormat) {
            packet.fmtVideoFormat.video_type = MacUnknown; //video engine can't support UYVY color space
        } else if (kCVPixelFormatType_422YpCbCr8_yuvs == pixelFormat) {
            packet.fmtVideoFormat.video_type = MacYUY2;
        } else if (kCVPixelFormatType_32ARGB == pixelFormat) {
            packet.fmtVideoFormat.video_type = MacARGB32;
        } else if (kCVPixelFormatType_32BGRA == pixelFormat) {
            packet.fmtVideoFormat.video_type = MacBGRA32;
        } else {
            packet.fmtVideoFormat.video_type = MacUnknown;
        }
        
        packet.pSrcData[0] =
        packet.pSrcData[1] =
        packet.pSrcData[2] = (unsigned char*)baseAddress;
        packet.uiSrcStride[0] =
        packet.uiSrcStride[1] =
        packet.uiSrcStride[2] = (unsigned int)bytesPerRow;
        packet.ulDataLen = dataSize;
    }
    
    return 0;
}
