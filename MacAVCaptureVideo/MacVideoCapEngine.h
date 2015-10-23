//
//  MacVideoCapEngine.h
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#ifndef MacAVCaptureVideo_MacVideoCapEngine_h
#define MacAVCaptureVideo_MacVideoCapEngine_h

#include "MacDatatypes.h"
#include "MacVideoCapSession.h"

class CMacAVVideoCapEngine : public IMacAVVideoCapSessionSink {
public:
    CMacAVVideoCapEngine();
    virtual ~CMacAVVideoCapEngine();
    
    long Init(MACCaptureSessionFormat &capSessioinFormat);
    void Uninit();

    CMacAVVideoCapSession *getAVVideoCapSession();
    
    long Start(MACCaptureSessionFormat &capSessionFormat);
    bool IsRunning();
    long Stop();
    long StartCapture(NSString *strCaptureFile);
    long StopCapture(unsigned long &totalFrames);
    bool IsCapturing();

    // update series;
    long UpdateAVCaptureDeviceFormat(AVCaptureDeviceFormat *format);
    long UpdateAVCaptureSessionPreset(NSString *preset);
    long UpdateAVCaptureSessionFPS(float fps);

    long DeliverVideoData(VideoRawDataPack* pVideoPack);
    
    // IMacAVVideoCapSessionSink
    long DeliverVideoData(CVImageBufferRef imageBuffer);

private:
    CMacAVVideoCapSession*  m_pVideoCapSession;
    MACCaptureSessionFormat m_capSessionFormat;
    
    bool m_bStartCapture;
    NSString *m_captureFile;
    NSLock *m_fileLock;
    NSFileHandle *m_fileHandle;
    unsigned long m_ulCounter;
};

int CVImageBuffer2VideoRawPacket(CVImageBufferRef imageBuffer, VideoRawDataPack &packet);

#endif
