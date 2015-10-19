//
//  MacLog.h
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#ifndef __MacAVCaptureVideo__MacLog__
#define __MacAVCaptureVideo__MacLog__

#include <assert.h>
#include <string>
#include <sstream>

typedef enum {
    MAC_LOG_LEVEL_INFO = 0,
    MAC_LOG_LEVEL_WARNING = 1,
    MAC_LOG_LEVEL_ERROR = 2,
    MAC_LOG_LEVEL_FATAL = 3,
} MAC_LOG_LEVEL_T;

class MacLog {
public:
    void Log(MAC_LOG_LEVEL_T level, const std::string &msg);
    static MacLog* singleton();

private:
    // constructor and destructor as private to make DmdLog Singleton.
    MacLog();
    explicit MacLog(MAC_LOG_LEVEL_T logLevel);
    virtual ~MacLog();

    MAC_LOG_LEVEL_T m_uLevel;

    static MacLog* s_Log;
};

#define MAC_LOG(level, msg) \
do { \
std::stringstream strstream; \
strstream << msg; \
MacLog::singleton()->Log(level, strstream.str()); \
} while (0)

#define MAC_LOG_INFO(msg) MAC_LOG(MAC_LOG_LEVEL_INFO, msg)
#define MAC_LOG_WARNING(msg) MAC_LOG(MAC_LOG_LEVEL_WARNING, msg)
#define MAC_LOG_ERROR(msg) MAC_LOG(MAC_LOG_LEVEL_ERROR, msg)
#define MAC_LOG_FATAL(msg) MAC_LOG(MAC_LOG_LEVEL_FATAL, msg)

#define MAC_CHECK_NOTNULL(ptr) \
do { \
assert(ptr); \
} while (0)


#endif // defined(__MacAVCaptureVideo__MacLog__)
