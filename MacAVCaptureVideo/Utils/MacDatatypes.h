//
//  MacDatatypes.h
//  MacAVCaptureVideo
//
//  Created by wzw on 10/20/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#ifndef MacAVCaptureVideo_MacDatatypes_h
#define MacAVCaptureVideo_MacDatatypes_h

#define MAC_S_FALSE							(0x00000001)
#define MAC_S_OK                            (0x00000000)
#define MAC_E_FAIL							(0x80000001)
#define MAC_E_INVALIDARG				    (0x80000003)
#define MAC_E_POINTER						(0x80000006)

//device
const long MAC_E_DEVICE_BASE = 0x46024100;
const long MAC_E_VIDEO_CAMERA_FAIL = MAC_E_DEVICE_BASE + 1;
const long MAC_E_VIDEO_CAMERA_NOT_AUTHORIZED = MAC_E_DEVICE_BASE + 2;
const long MAC_E_VIDEO_CAMERA_NO_DEVICE = MAC_E_DEVICE_BASE + 3;

//currently only support these input video format
typedef enum
{
    MacUnknown   = 0,
    /*yuv color formats*/
    MacI420,
    MacYV12,
    MacNV12,
    MacNV21,
    MacYUY2,
    /*rgb color formats*/
    MacRGB24,
    MacBGR24,
    MacRGB24Flip,
    MacBGR24Flip,
    MacRGBA32,
    MacBGRA32,
    MacARGB32,
    MacABGR32,
    MacRGBA32Flip,
    MacBGRA32Flip,
    MacARGB32Flip,
    MacABGR32Flip,
} MacVideoType;

typedef struct _video_format
{
    MacVideoType	video_type;
    unsigned long	width;
    unsigned long	height;
    float	        frame_rate;
    unsigned long   time_stamp;
} MacVideoFormat;

#define MAX_PLANE_COUNT	3
#ifndef MAX_PLANAR_NUM
#define MAX_PLANAR_NUM 4
#endif

typedef struct
{
    unsigned char *pSrcData[MAX_PLANAR_NUM];
    unsigned int   uiSrcStride[MAX_PLANAR_NUM];
    MacVideoFormat fmtVideoFormat;
    unsigned int   uiRotation;
    unsigned long  ulDataLen;
} VideoRawDataPack;

#endif
