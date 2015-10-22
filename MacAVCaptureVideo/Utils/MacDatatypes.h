//
//  MacDatatypes.h
//  MacAVCaptureVideo
//
//  Created by wzw on 10/20/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

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

// Y'CbCr 4:2:2 - yuvs: kCVPixelFormatType_422YpCbCr8_yuvs
// Y'CbCr 4:2:2 - uyuv: kCVPixelFormatType_422YpCbCr8
// Y'CbCr 4:2:0 - 420v: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
typedef enum
{
    MacUnknown   = 0,
    Macyuyv = kCVPixelFormatType_422YpCbCr8_yuvs,
    Macuyvy = kCVPixelFormatType_422YpCbCr8,
    MAC420v = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
} MacVideoType;

typedef struct _output_format
{
    MacVideoType    video_type;
    int             width;
    int             height;
} MacVideoOutputFormat;

typedef struct _video_format
{
    MacVideoType    video_type;
    size_t          width;
    size_t          height;
    float           frame_rate;
    NSTimeInterval  time_stamp;
} MacVideoSampleFormat;

typedef struct _capsession_format
{
    AVCaptureDevice *capDevice;
    AVCaptureDeviceFormat *capFormat;
    NSString *capSessionPreset;
    float capFPS;
} MACCaptureSessionFormat;

#define MAX_PLANE_COUNT	3
#ifndef MAX_PLANAR_NUM
#define MAX_PLANAR_NUM 4
#endif

typedef struct
{
    unsigned char   *pSrcData[MAX_PLANAR_NUM];
    size_t          ulSrcStride[MAX_PLANAR_NUM];
    size_t          ulSrcDatalen[MAX_PLANAR_NUM];
    MacVideoSampleFormat fmtVideoFormat;
    size_t          ulPlaneCount;
    unsigned int    ulRotation;
    size_t          ulDataLen;
} VideoRawDataPack;

#endif
