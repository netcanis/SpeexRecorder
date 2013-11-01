//
//  SpeexRecorder.h
//  Speex Recorder
//
//  Created by ChenXJ on 13-10-23.
//  Copyright (c) 2013年 Yuantel.com. All rights reserved.
//

#ifndef __SpeexRecorder__SpeexRecorder__
#define __SpeexRecorder__SpeexRecorder__

#import <AudioToolbox/AudioToolbox.h>
#include <stdio.h>
#include <ogg/ogg.h>
#include <speex/speex.h>



#define kNumberRecordBuffers	3
/**
speex 编码文件录音
文件输出格式：ogg
语音编码：speex
*/
class SpeexRecorder {
public:
    SpeexRecorder();
    ~SpeexRecorder();
    Boolean record(const char *fileName,int compression,int modeID);
    void stop();
    Boolean isRecording(){return mIsRecording;}
    //获取录音时长（单位：ms)
    long getRecordTime();
    long getFileLength(){return mfilelen;}
private:
    Boolean mIsRecording;
	
	//ogg
	int granulepos;
	int lookahead;
	ogg_stream_state m_os;
	ogg_page 		 m_og;
	ogg_packet 		 m_op;
	
	int oe_write_page();
	Boolean writeOggHeader();
	
	//speex
	void *encodeState;
    SpeexBits encodeSpeexBits;
	const int mFramesPerPacket=10; //每个包中的语音帧数
	int mFrameSize;                 //每帧语音长度
	//打开speex 编码器
	Boolean openEncode(int compression, int modeID);
    
    short *mFrameBuffer;
    int mFrameDatalen;
    int mFrames;
    
    //录音抽样总数
    long mTotalSamples;
    //录音抽样速率
    int mRate;
	
	FILE *mfd;
    long mfilelen;
	
	AudioQueueRef mQueue;
    AudioQueueBufferRef mQueueBufferRef[kNumberRecordBuffers];

    AudioStreamBasicDescription	mRecordFormat;

    
    static void InputBufferHandler(	void *	inUserData,
											AudioQueueRef						inAQ,
											AudioQueueBufferRef					inBuffer,
											const AudioTimeStamp *				inStartTime,
											UInt32								inNumPackets,
											const AudioStreamPacketDescription*	inPacketDesc);

    void doInputBufferHandler(
											AudioQueueRef						inAQ,
											AudioQueueBufferRef					inBuffer,
											const AudioTimeStamp *				inStartTime,
											UInt32								inNumPackets,
											const AudioStreamPacketDescription*	inPacketDesc);
    void Dispose();
};

#endif /* defined(__SpeexRecorder__SpeexRecorder__) */
