//
//  SpeexRecorder.cpp
//  Speex Recorder
//
//  Created by ChenXJ on 13-10-23.
//  Copyright (c) 2013年 Yuantel.com. All rights reserved.
//

#include "SpeexRecorder.h"
#include <speex/speex_header.h>


#define readint(buf, base) (((buf[base+3]<<24)&0xff000000)| \
                           ((buf[base+2]<<16)&0xff0000)| \
                           ((buf[base+1]<<8)&0xff00)| \
  	           	    (buf[base]&0xff))
#define writeint(buf, base, val) { buf[base+3]=((val)>>24)&0xff; \
                                     buf[base+2]=((val)>>16)&0xff; \
                                     buf[base+1]=((val)>>8)&0xff; \
                                     buf[base]=(val)&0xff; \
                                 }

void comment_init(char **comments, int* length, char *vendor_string)
{
  int vendor_length=strlen(vendor_string);
  int user_comment_list_length=0;
  int len=4+vendor_length+4;
  char *p=(char*)malloc(len);
  if(p==NULL){
     fprintf (stderr, "malloc failed in comment_init()\n");
     exit(1);
  }
  writeint(p, 0, vendor_length);
  memcpy(p+4, vendor_string, vendor_length);
  writeint(p, 4+vendor_length, user_comment_list_length);
  *length=len;
  *comments=p;
}
void comment_add(char **comments, int* length, char *tag, char *val)
{
  char* p=*comments;
  int vendor_length=readint(p, 0);
  int user_comment_list_length=readint(p, 4+vendor_length);
  int tag_len=(tag?strlen(tag):0);
  int val_len=strlen(val);
  int len=(*length)+4+tag_len+val_len;

  p=(char*)realloc(p, len);
  if(p==NULL){
     fprintf (stderr, "realloc failed in comment_add()\n");
      return;
  }

  writeint(p, *length, tag_len+val_len);      /* length of comment */
  if(tag) memcpy(p+*length+4, tag, tag_len);  /* comment */
  memcpy(p+*length+4+tag_len, val, val_len);  /* comment */
  writeint(p, 4+vendor_length, user_comment_list_length+1);

  *comments=p;
  *length=len;
}
#undef readint
#undef writeint

SpeexRecorder::SpeexRecorder():
mfd(NULL)
,mQueue(0)	
,mIsRecording(false)
,encodeState(NULL)
,mFrameBuffer(NULL)
,mTotalSamples(0L)
,mfilelen(0L)
{

    memset(&mRecordFormat, 0, sizeof(mRecordFormat));
 
    
   mRecordFormat.mFramesPerPacket = 1;
   mRecordFormat.mChannelsPerFrame = 1;
   mRecordFormat.mFormatID =  kAudioFormatLinearPCM;
   mRecordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
   mRecordFormat.mBitsPerChannel = 16;
   mRecordFormat.mBytesPerPacket = mRecordFormat.mBytesPerFrame = (mRecordFormat.mBitsPerChannel / 8) * mRecordFormat.mChannelsPerFrame;
   
 
 
    
    
    for (int i = 0; i < kNumberRecordBuffers; ++i) {
        mQueueBufferRef[i] = NULL;
    }

}

SpeexRecorder::~SpeexRecorder()
{
    stop();
}

Boolean SpeexRecorder::openEncode(int compression, int modeID)
{
    const SpeexMode *mode=NULL;
   
    speex_bits_init(&encodeSpeexBits);    
    mode = speex_lib_get_mode (modeID);
	if(mode==NULL)return false;
    encodeState = speex_encoder_init(mode);  
	
    speex_encoder_ctl(encodeState, SPEEX_SET_QUALITY, &compression);  
    speex_encoder_ctl(encodeState, SPEEX_GET_FRAME_SIZE, &mFrameSize);  
     
    speex_bits_reset(&encodeSpeexBits);
	
	speex_encoder_ctl(encodeState, SPEEX_GET_LOOKAHEAD, &lookahead);
    
    speex_encoder_ctl(encodeState, SPEEX_GET_SAMPLING_RATE,&mRate);
	 
	return true;
}
 
int SpeexRecorder::oe_write_page()
{
   int written;
   written = fwrite(m_og.header,1,m_og.header_len, mfd);
   written += fwrite(m_og.body,1,m_og.body_len, mfd);

   printf("written:%d,real len=%ld\n",written,m_og.header_len+m_og.body_len);
    mfilelen += written ;
   return written;
}

Boolean SpeexRecorder::writeOggHeader()
{
    SpeexHeader header;
	
   /*Initialize Ogg stream struct*/
   srand(time(NULL));
   ogg_stream_init(&m_os, rand());
   
   int rate;
   speex_encoder_ctl(encodeState, SPEEX_GET_SAMPLING_RATE, &rate); 
   
   speex_init_header(&header, rate, 1,  *(SpeexMode**)encodeState);
   header.frames_per_packet= mFramesPerPacket;
   header.vbr=0;
   header.nb_channels = 1; //单声道
   
 
   /*Write header*/
   {
      int packet_size;
      m_op.packet = (unsigned char *)speex_header_to_packet(&header, &packet_size);
      m_op.bytes = packet_size;
      m_op.b_o_s = 1;
      m_op.e_o_s = 0;
      m_op.granulepos = 0;
      m_op.packetno = 0;
      ogg_stream_packetin(&m_os, &m_op);
      free(m_op.packet);

      while( ogg_stream_flush(&m_os, &m_og))
      {
         oe_write_page();
      }
	}  
   
   char vendor_string[64];
   const char* speex_version;
   char *comments;
   int comments_length;
   
   speex_lib_ctl(SPEEX_LIB_GET_VERSION_STRING, (void*)&speex_version);
   snprintf(vendor_string, sizeof(vendor_string), "Encoded with Speex %s,yuantel.com", speex_version);
   comment_init(&comments, &comments_length, vendor_string);

   m_op.packet = (unsigned char *)comments;
   m_op.bytes = comments_length;
   m_op.b_o_s = 0;
   m_op.e_o_s = 0;
   m_op.granulepos = 0;
   m_op.packetno = 1;
   ogg_stream_packetin(&m_os, &m_op);
   
   while( ogg_stream_flush(&m_os, &m_og))
   {     
      oe_write_page();      
   }

   free(comments);
   return true;
}

void SpeexRecorder::InputBufferHandler(	void *	inUserData,
											AudioQueueRef						inAQ,
											AudioQueueBufferRef					inBuffer,
											const AudioTimeStamp *				inStartTime,
											UInt32								inNumPackets,
											const AudioStreamPacketDescription*	inPacketDesc)
{
   SpeexRecorder *THIS = (SpeexRecorder *)inUserData;
   THIS->SpeexRecorder::doInputBufferHandler(
																inAQ,
														inBuffer,
														inStartTime,
																	inNumPackets,
												inPacketDesc);
}											

void SpeexRecorder::doInputBufferHandler(
											AudioQueueRef						inAQ,
											AudioQueueBufferRef					inBuffer,
											const AudioTimeStamp *				inStartTime,
											UInt32								inNumPackets,
											const AudioStreamPacketDescription*	inPacketDesc)
{
    printf("doInputBufferHandler,len=%d,inNumPackets=%ld\n",(int)inBuffer->mAudioDataByteSize
           ,inNumPackets);
 
    short *buff = (short*) (inBuffer->mAudioData);
    int samples = inNumPackets;
    
    if(inBuffer->mAudioDataByteSize==0)
    {
       if(mfd!=NULL&&mIsRecording==false)
        {
            goto writedata;
        }
        return;
    }
    
 
    mTotalSamples += inNumPackets;
   if(mFrameDatalen>0)
   {
       printf("mFrameDatalen=%d\n",mFrameDatalen);
       if(inNumPackets+mFrameDatalen>=mFrameSize)
       {
           int n = mFrameSize-mFrameDatalen;
           memcpy(&(mFrameBuffer[mFrameDatalen]),buff,n*sizeof(short));
           buff += n;
           samples -= n;
           mFrameDatalen = 0;
           
           speex_encode_int(encodeState, mFrameBuffer, &encodeSpeexBits);
           granulepos += mFrameSize;
           mFrames++;
       }
       else
       {
           memcpy(&(mFrameBuffer[mFrameDatalen]),buff,samples*sizeof(short));
           mFrameDatalen += samples;
           samples = 0;
       }
    
       
//    printf("Audio Data len=%d\n",(int)(inBuffer->mAudioDataByteSize));
   }
writedata:
do
{
   for(;mFrames<mFramesPerPacket&&samples>=mFrameSize;mFrames++)
   {
     
      speex_encode_int(encodeState, buff, &encodeSpeexBits);
	  granulepos += mFrameSize;
      buff += mFrameSize;
       samples -= mFrameSize;
   }
   printf("mFrames=%d\n",mFrames);
    
   if(mFrames==mFramesPerPacket||(mIsRecording==false&&mFrames>0))
   {
       int size = mFrameSize*mFramesPerPacket;

       m_op.packet =(unsigned char *)inBuffer->mAudioData;
    
       m_op.bytes  = speex_bits_write(&encodeSpeexBits, (char*)m_op.packet, size);
       m_op.b_o_s = 0;
       if(mIsRecording||samples>=mFrameSize)
           m_op.e_o_s = 0;
       else
           m_op.e_o_s = 1;
				
       m_op.granulepos = granulepos-lookahead;
       m_op.packetno++;
  
       speex_bits_reset(&encodeSpeexBits);
       
       printf("packetno=%lld,size=%ld,m_op.e_o_s=%ld\n",m_op.packetno,m_op.bytes,m_op.e_o_s);
       ogg_stream_packetin(&m_os, &m_op);

       while(ogg_stream_pageout(&m_os,&m_og))
       {
           oe_write_page();
       }
       mFrames = 0;
   }
   
   if(samples<mFrameSize)
   {
       if(mIsRecording)
       {
           memcpy(mFrameBuffer,buff,samples*sizeof(short));
           mFrameDatalen = samples;
       }
      
       samples = 0;
       break;
   }
    
} while(samples>0);
    

   if(mIsRecording)
   {
       AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
   }
 
}

Boolean SpeexRecorder::record(const char *fileName,int compression,int modeID)
{
   OSStatus ostatus;
  
 
   if(mIsRecording||mfd!=NULL)return false;
    
   printf("record:%s,compression=%d,modeID=%d\n",fileName,compression,modeID);
    
    mfilelen = 0;
   mfd = fopen(fileName,"wb");
   if(mfd==NULL)
   {
      fprintf(stderr,"Can't open %s\n",fileName);
	  return false;
   }
   if(!openEncode(compression, modeID))
   {
       fprintf(stderr,"open encode fail!compression:%d,modeID=%d\n",compression,modeID);
       Dispose();
      return false;
   }
   
   writeOggHeader();
    
    
      
   mRecordFormat.mSampleRate = mRate;
     
    
  
   ostatus = AudioQueueNewInput(&mRecordFormat,
									  SpeexRecorder::InputBufferHandler,
									  this /* userData */,
									  NULL /* run loop */, NULL /* run loop mode */,
									  0 /* flags */, &mQueue);
    if(ostatus!=noErr)
    {
        fprintf(stderr, "AudioQueueNewInput err=%d\n",(int)ostatus);
        Dispose();
        return false;
    }
    
    mFrameBuffer = (short *)malloc(mFrameSize * sizeof(short));
    mFrameDatalen = 0;
    mFrames = 0;
    int bufferByteSize = mFramesPerPacket * mFrameSize * sizeof(short);
									  
    for (int i = 0; i < kNumberRecordBuffers; ++i) {
			AudioQueueAllocateBuffer(mQueue, bufferByteSize, &mQueueBufferRef[i]);					   
			AudioQueueEnqueueBuffer(mQueue, mQueueBufferRef[i], 0, NULL);
					  
    }
   
    mTotalSamples = 0L;
                                
    AudioQueueStart(mQueue,NULL);
	mIsRecording = true;
	return true;
}

long SpeexRecorder::getRecordTime()
{
    return mTotalSamples*1000/mRate;
}

void SpeexRecorder::stop()
{
    printf("stop record\n");
    mIsRecording = false;
    if(mQueue!=NULL)
    {
       
        AudioQueueStop(mQueue, true);
        printf("AudioQueueStop ok\n");
        
        
        while (ogg_stream_flush(&m_os, &m_og))
        {
            oe_write_page();
        }
        printf("record file len=%ld\n",ftell(mfd));
        
        Dispose();
        

       

    }
    printf("stop record over\n");
}

void SpeexRecorder::Dispose()
{
    printf("SpeexRecorder::Dispose()\n");

     if(encodeState)
     {
         speex_encoder_destroy(encodeState);
         speex_bits_destroy(&encodeSpeexBits);
     }
        
     ogg_stream_clear(&m_os);
    
    if(mFrameBuffer!=NULL)
    {
        free(mFrameBuffer);
        mFrameBuffer = NULL;
    }
    
    if(mfd!=NULL)
    {
        
        
        fclose(mfd);
        mfd = NULL;
        
    }
    if(NULL!=mQueue)
    {
        
        for (int i = 0; i < kNumberRecordBuffers; ++i)
        {
            if(mQueueBufferRef[i]!=NULL)
            {
                AudioQueueFreeBuffer(mQueue,mQueueBufferRef[i]);
                mQueueBufferRef[i] = NULL;
            }
        }
        AudioQueueDispose(mQueue, true);
        mQueue = NULL;
    }

    printf("Dispose\n");
}
