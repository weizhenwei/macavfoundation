//
//  MacLog.cpp
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#include "MacLog.h"

#include <stdio.h>
#include <stdarg.h>
#include <string>
#include <map>

#include "MacLog.h"

MacLog* MacLog::s_Log = NULL;
static std::map<int, std::string> mapLogLevel = {
    std::pair<int, std::string>(MAC_LOG_LEVEL_INFO, "INFO"),
    std::pair<int, std::string>(MAC_LOG_LEVEL_WARNING, "WARNING"),
    std::pair<int, std::string>(MAC_LOG_LEVEL_ERROR, "ERROR"),
    std::pair<int, std::string>(MAC_LOG_LEVEL_FATAL, "FATAL"),
};


MacLog::MacLog() : m_uLevel(MAC_LOG_LEVEL_INFO) {
}

MacLog::MacLog(MAC_LOG_LEVEL_T logLevel) : m_uLevel(logLevel) {
}

MacLog::~MacLog() {
}

void MacLog::Log(MAC_LOG_LEVEL_T level, const std::string &msg) {
    if (level < MAC_LOG_LEVEL_INFO || level > MAC_LOG_LEVEL_FATAL)
        return;
    if (level < m_uLevel)
        return;

    fprintf(stdout, "%s:%s\n", mapLogLevel[level].c_str(), msg.c_str());
}

MacLog* MacLog::singleton() {
    if (s_Log) {
        return s_Log;
    } else {
        s_Log = new MacLog(MAC_LOG_LEVEL_INFO);
        MAC_CHECK_NOTNULL(s_Log);
        return s_Log;
    }
}
