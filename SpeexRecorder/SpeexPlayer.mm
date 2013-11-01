//
//  SpeexPlayer.cpp
//  SpeexRecorder
//
//  Created by Chenxj on 13-10-23.
//  Copyright (c) 2013年 Yuantel.com. All rights reserved.
//

#include "SpeexPlayer.h"
#include <speex/speex_header.h>
/*
 使用AudioQueue来实现音频播放功能时最主要的步骤，可以更简练的归纳如下。
1. 打开播放音频文件
2. 取得播放音频文件的数据格式
3. 准备播放用的队列
4. 将缓冲中的数据移动到队列中
5. 开始播放
6. 在回调函数中进行队列处理
*/

SpeexPlayer::SpeexPlayer()
:mQueue(0),
mIsRunning(false),
mIsInitialized(false),
mIsDone(false),
decodeState(NULL)
,isStreamInit(false)
{
  	for(int i=0;i<NUM_BUFFERS;i++) {
	  queueBufferRef[i] = NULL;
	}
	 
}
SpeexPlayer::~SpeexPlayer()
{
    Dispose();
}

/**
* 从Ogg格式数据文件流中读取一个数据包
*/
Boolean SpeexPlayer::readpacket()
{

	   while(!isStreamInit||!ogg_stream_packetout(&oggStreamState,&oggPacket)) 
	   {		   
		  
		   if(ogg_sync_pageout(&oggSyncState,&oggPage))
		   {
  //            printf("read one page\n");
		      if(!isStreamInit) {
		        ogg_stream_init(&oggStreamState, ogg_page_serialno(&oggPage));
				isStreamInit = true;
			  }
			  else {
				
			        if (ogg_page_serialno(&oggPage) != oggStreamState.serialno) {
						
	                   ogg_stream_reset_serialno(&oggStreamState, ogg_page_serialno(&oggPage));
	                }
			  }
			  ogg_stream_pagein(&oggStreamState,&oggPage);
			  continue;
			}		 
		   
		  char * data=  ogg_sync_buffer(&oggSyncState,200);
		  int l = fread(data, sizeof(char), 200, mfd);
      //     printf("read len=%d\n",l);
		  if(l<=0)return false;
		
		  ogg_sync_wrote(&oggSyncState, l);
						
	   }
	   return true;
}


//处理speex 头部信息
Boolean SpeexPlayer::process_header()
{
    OSStatus osstate;
	SpeexHeader *header = speex_packet_to_header((char*)oggPacket.packet, oggPacket.bytes);
	if(header==NULL)
	{
	   fprintf (stderr, "Cannot read speex header\n");	 
	   return false;
	}
   // printf("speex header mode =%d,rate=%d,frames_perr_packet=%d\n",(int)header->mode,header->rate,
   //        header->frames_per_packet);
    
   if (header->speex_version_id > 1)
   {
      fprintf (stderr, "This file was encoded with Speex bit-stream version %d, which I don't know how to decode\n", header->speex_version_id);
      free(header);
      return NULL;
   }
   const SpeexMode *mode = speex_lib_get_mode (header->mode);
	
   if (mode->bitstream_version < header->mode_bitstream_version)
   {
      fprintf (stderr, "The file was encoded with a newer version of Speex. You need to upgrade in order to play it.\n");
      free(header);
      return NULL;
   }
   if (mode->bitstream_version > header->mode_bitstream_version) 
   {
      fprintf (stderr, "The file was encoded with an older version of Speex. You would need to downgrade the version in order to play it.\n");
      free(header);
      return NULL;
   }
   decodeState = speex_decoder_init(mode);
    
   if (!decodeState)
   {
      fprintf (stderr, "Decoder initialization failed.\n");
      free(header);
      return NULL;
   }
   
   mFramesPerPacket = header->frames_per_packet;
   speex_decoder_ctl(decodeState, SPEEX_GET_FRAME_SIZE, &mFrameSize); 
   
    
    audioDescription.mSampleRate = header->rate;//采样率
    audioDescription.mFormatID = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioDescription.mChannelsPerFrame = 1;///单声道
    audioDescription.mFramesPerPacket = 1;//每一个packet一侦数据
    audioDescription.mBitsPerChannel = 16;//每个采样点16bit量化
    audioDescription.mBytesPerFrame = (audioDescription.mBitsPerChannel/8) * audioDescription.mChannelsPerFrame;
    audioDescription.mBytesPerPacket = audioDescription.mBytesPerFrame ;
	
   osstate = AudioQueueNewOutput(&audioDescription,SpeexPlayer::BufferCallack, this, NULL, NULL, 0, & mQueue);
   if(osstate!=noErr)
   {
       fprintf(stderr, "AudioQueueNewOutput ,err=%d\n",(int)osstate);
       return false;
   }
    
   //添加buffer区
   int packetlen = mFrameSize * mFramesPerPacket *sizeof(short);
   
    for(int i=0;i<NUM_BUFFERS;i++) {
     //   int result = 
		AudioQueueAllocateBuffer(mQueue,packetlen , &queueBufferRef[i]);
       // NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d",i,result);
    }

   
   free(header);
   return true;
}
//暂停播音
Boolean SpeexPlayer::pause()
{
  
    return    AudioQueuePause(mQueue)==noErr;
  
}
//继续放音
//TODO
Boolean SpeexPlayer::resume()
{
    return false;
}
void SpeexPlayer::Dispose()
{
    printf("SpeexPlayer::Dispose\n");
    if (mQueue)
	{
        
        
		for(int i=0;i<NUM_BUFFERS;i++)
		{
			if(queueBufferRef[i]!=NULL)
			{
				AudioQueueFreeBuffer(mQueue,queueBufferRef[i]);
				queueBufferRef[i] = NULL;
			}
		}
        
        AudioQueueDispose(mQueue, true);
		mQueue = NULL;
	}
    
    if(decodeState!=NULL)
	{
     //   printf("speex_bits_destroy\n");

        speex_bits_destroy(&decodeSpeexBits);
        speex_decoder_destroy(decodeState); 
     //   printf("speex_decoder_destroy ok\n");
        decodeState = NULL;
	}
	
	if(isStreamInit)
	{
        ogg_stream_clear(&oggStreamState);
        isStreamInit = false;
	}
	ogg_sync_clear(&oggSyncState);
	
	if(mfd!=NULL)
	{
        fclose(mfd);
        mfd = NULL;
	}

}

void SpeexPlayer::stop()
{
    if(!mIsDone)
    {
        mIsDone = true;
    
        if (mQueue)
        {
            printf("AudioQueueStop\n");
            AudioQueueStop(mQueue, true);
        }
    }
    printf("SpeexPlayer::stop() over\n");
  
}

void SpeexPlayer::doBufferCallack(AudioQueueRef inAQ, AudioQueueBufferRef bufferRef)
{
    if(mIsDone )return ;
    
    if(readpacket())
	{
	   short *buffer = (short *)(bufferRef->mAudioData);
       speex_bits_read_from(&decodeSpeexBits, (char *)oggPacket.packet, oggPacket.bytes);
       int i;
	   for(i=0;i<mFramesPerPacket;i++)
	   {
	      
           if(speex_decode_int(decodeState, &decodeSpeexBits, buffer +(i*mFrameSize)))break;
	   }
       bufferRef->mAudioDataByteSize = i*mFrameSize*sizeof(short);
        
 //       printf("buff len=%ld\n",bufferRef->mAudioDataByteSize);
	
	   AudioQueueEnqueueBuffer(inAQ, bufferRef, 0, NULL);
  //     printf("read buffer len=%d\n",(int)bufferRef->mAudioDataByteSize);
	}
    else
    {
     
        stop();
        
    }
}
void SpeexPlayer::doIsRunningProc(AudioQueueRef           inAQ,
                     AudioQueuePropertyID    inID)
{
    UInt32 size = sizeof(mIsRunning);
	OSStatus result = AudioQueueGetProperty (inAQ, kAudioQueueProperty_IsRunning,
                                             &mIsRunning, &size);

	if ((result == noErr) && (!mIsRunning))
    {
        Dispose();
        
		[[NSNotificationCenter defaultCenter] postNotificationName: @"playbackQueueStopped" object: nil];
        
        printf("postNotification\n");
    
    }
   
}


void SpeexPlayer::isRunningProc (  void *              inUserData,
                              AudioQueueRef           inAQ,
                              AudioQueuePropertyID    inID)
{
    printf("SpeexPlayer::isRunningProc\n");
	SpeexPlayer *THIS = (SpeexPlayer *)inUserData;
    THIS->doIsRunningProc(inAQ, inID);
}
void SpeexPlayer::BufferCallack(void *inUserData,AudioQueueRef inAQ,AudioQueueBufferRef buffer)
{
    SpeexPlayer *THIS = (SpeexPlayer*)inUserData;
    THIS->doBufferCallack(inAQ,buffer);
    
    
}

Boolean SpeexPlayer::play(const char *fileName)
{
    if(mIsRunning||fileName==NULL)return false;
	

    printf("play file:%s\n",fileName);
	
	mfd = fopen(fileName,"rb");
	if(mfd==NULL)
	{
	   fprintf(stderr,"Can't open %s\n",fileName);
	   return false;
	}
    
			
    ogg_sync_init(&oggSyncState);
	speex_bits_init(&decodeSpeexBits);
	
	isStreamInit = false;
  
	if(!readpacket()||!process_header())
	{
        Dispose();
	   return false;
	}
	//no 2  comment
	if(!readpacket())
    {
        Dispose();
        return false;
    }
    
    AudioQueueAddPropertyListener(mQueue, kAudioQueueProperty_IsRunning, isRunningProc, this);
    mIsDone = false;

	for(int i=0;i<NUM_BUFFERS;i++) {
	  doBufferCallack(mQueue,queueBufferRef[i]);
	}
    //开始播音
    AudioQueueStart(mQueue, NULL);
  
    return true;
}
