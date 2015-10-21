#!/bin/bash

headerline=`find ./MacAVCaptureVideo -name \*.h | xargs cat | wc -l`;
cline=`find ./MacAVCaptureVideo -name \*.c | xargs cat | wc -l`;
cppline=`find ./MacAVCaptureVideo -name \*.cpp | xargs cat | wc -l`;
objcline=`find ./MacAVCaptureVideo -name \*.m | xargs cat | wc -l`;
objcppline=`find ./MacAVCaptureVideo -name \*.mm | xargs cat | wc -l`;

totalline=`expr $headerline + $cline + $cppline \
           + $objcline + $objcppline`;
echo "total code written in project = $totalline";
