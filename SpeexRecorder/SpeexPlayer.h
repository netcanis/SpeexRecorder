//
//  SpeexPlayer.h
//  SpeexRecorder
//
//  Created by ChenXJ on 13-10-23.
//  Copyright (c) 2013年 Yuantel.com. All rights reserved.
//

#ifndef __SpeexRecorder__SpeexPlayer__
#define __SpeexRecorder__SpeexPlayer__

#import <AudioToolbox/AudioToolbox.h>
#include <stdio.h>


#include <ogg/ogg.h>
#include <speex/speex.h>

#define NUM_BUFFERS 3

/**
 Speex 语音播放器
 播放文件格式 Ogg
 文件编码：speex
 */
class SpeexPlayer {
public:
    SpeexPlayer();
    ~SpeexPlayer();
    Boolean play(const char *fileName);
    //暂停播音
    Boolean pause();
    //继续放音
    Boolean resume();
    void stop();
   Boolean	IsRunning()	const { return (mIsRunning) ? true : false; }
    void doBufferCallack(AudioQueueRef inAQ, AudioQueueBufferRef buffer);
    void doIsRunningProc(AudioQueueRef           inAQ,
                       AudioQueuePropertyID    inID);
private:
    Boolean		mIsInitialized;
    UInt32							mIsRunning;
    Boolean							mIsDone;
	FILE *mfd;
	//ogg
    ogg_stream_state oggStreamState;
    ogg_sync_state   oggSyncState;
    ogg_packet       oggPacket;
    ogg_page         oggPage;
    int packetNo;
	Boolean isStreamInit;
    //speex
    void *decodeState;
    SpeexBits decodeSpeexBits;
	int mFramesPerPacket; //每个包中的语音帧数
	int mFrameSize;       //每帧语音长度
	//-----------------------------------------------
    
    AudioQueueRef mQueue;
    AudioQueueBufferRef queueBufferRef[NUM_BUFFERS];
	AudioStreamBasicDescription audioDescription;///音频参数
    
    static void BufferCallack(void *inUserData,AudioQueueRef inAQ, AudioQueueBufferRef buffer);
    static void isRunningProc(void *              inUserData,
                              AudioQueueRef           inAQ,
                              AudioQueuePropertyID    inID);
	
	Boolean readpacket();
	Boolean process_header();
    
    void Dispose();

};

#endif /* defined(__SpeexRecorder__SpeexPlayer__) */
