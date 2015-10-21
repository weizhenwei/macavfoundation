//
//  MacVideoCapSession.h
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#ifndef MacAVCaptureVideo_MacVideoCapSession_h
#define MacAVCaptureVideo_MacVideoCapSession_h

#import <AVFoundation/AVFoundation.h>

#import "MacDatatypes.h"

class CMacAVVideoCapEngine;
class IMacAVVideoCapSessionSink;

@interface CMacAVVideoCapSession : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    id							m_captureSession;               // AVCaptureSession
    id							m_videoCaptureDevice;           // AVCaptureDevice
    id							m_videoCaptureInput;            // AVCaptureDeviceInput
    id							m_videoCaptureDataOutput;       // AVCaptureVideoDataOutput
    
    AVCaptureVideoOrientation	m_videoOrientation;

    MACCaptureSessionFormat     m_format;

    IMacAVVideoCapSessionSink*  m_sink;
    NSRecursiveLock*            m_sinkLock;

    float                       m_systemVersion;
}

- (id)init;

- (AVCaptureSession *)getAVCaptureSesion;
- (void)setSink:(IMacAVVideoCapSessionSink*)sink;

- (BOOL)isRunning;
- (long)startRun:(MACCaptureSessionFormat&)format;
- (long)stopRun;
- (void)captureCleanup;

- (long)setCapSessionFormat:(MACCaptureSessionFormat&)format;
- (long)getCapSessionFormat:(MACCaptureSessionFormat&)format;
@end


class IMacAVVideoCapSessionSink
{
public:
    virtual ~IMacAVVideoCapSessionSink() {}
    
    virtual int DeliverVideoData(CVImageBufferRef imageBuffer) = 0;
};

#endif
