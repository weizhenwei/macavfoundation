//
//  MacVideoCapEngine.h
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#ifndef MacAVCaptureVideo_MacVideoCapEngine_h
#define MacAVCaptureVideo_MacVideoCapEngine_h

#include "MacVideoCapSession.h"

class CMacAVVideoCapEngine : public IMacAVVideoCapSessionSink {
public:
    CMacAVVideoCapEngine();
    virtual ~CMacAVVideoCapEngine();
    
    int Init(MacVideoFormat *format, NSString *deviceName);
    void Uninit();
    
    long Start();
    long Stop();
    
    int DeliverVideoData(VideoRawDataPack* pVideoPack);
    
    // IMacAVVideoCapSessionSink
    int DeliverVideoData(CVImageBufferRef imageBuffer);
    
private:
    CMacAVVideoCapSession*  m_pVideoCapSession;
    MacVideoFormat          m_videoFormat;
    NSString*               m_pDeviceName;
};

int CVImageBuffer2VideoRawPacket(CVImageBufferRef imageBuffer, VideoRawDataPack &packet);

#endif
