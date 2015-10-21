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
    long Stop();
    
    // update series;
    long UpdateAVCaptureDeviceFormat(AVCaptureDeviceFormat *format);
    long UpdateAVCaptureSessionPreset(NSString *preset);
    long UpdateAVCaptureSessionFPS(float fps);

    int DeliverVideoData(VideoRawDataPack* pVideoPack);
    
    // IMacAVVideoCapSessionSink
    int DeliverVideoData(CVImageBufferRef imageBuffer);
    
private:
    CMacAVVideoCapSession*  m_pVideoCapSession;
    MACCaptureSessionFormat m_capSessionFormat;
};

int CVImageBuffer2VideoRawPacket(CVImageBufferRef imageBuffer, VideoRawDataPack &packet);

#endif
