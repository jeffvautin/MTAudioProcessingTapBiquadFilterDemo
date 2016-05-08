//
//  processedAudioPlayer.m
//  mtaudioprocessingtapTestObjC
//
//  Created by Jeff Vautin on 5/7/16.
//  Copyright © 2016 Jeff Vautin. All rights reserved.
//

#import "ProcessedAudioPlayer.h"
@import AVFoundation;
@import Accelerate;

#define CHANNEL_LEFT 0
#define CHANNEL_RIGHT 1
#define NUM_CHANNELS 2

#pragma mark - Struct

typedef struct FilterState {
    float *gInputKeepBuffer[NUM_CHANNELS];
    float *gOutputKeepBuffer[NUM_CHANNELS];
    float coefficients[5];
    float gain;
} FilterState;

#pragma mark - Audio Processing

static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    
    char errorString[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(errorString, "%d", (int)error);
    
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    
    exit(1);
}

OSStatus BiquadFilter(float* inCoefficients,
                      float* ioInputBufferInitialValue,
                      float* ioOutputBufferInitialValue,
                      CMItemCount inNumberFrames,
                      void* ioBuffer) {
    
    // Provide buffer for processing
    float tInputBuffer[inNumberFrames + 2];
    float tOutputBuffer[inNumberFrames + 2];
    
    // Copy the two frames we stored into the start of the inputBuffer, filling the rest with the current buffer data
    memcpy(tInputBuffer, ioInputBufferInitialValue, 2 * sizeof(float));
    memcpy(tOutputBuffer, ioOutputBufferInitialValue, 2 * sizeof(float));
    memcpy(&(tInputBuffer[2]), ioBuffer, inNumberFrames * sizeof(float));
    
    // Do the filtering
    vDSP_deq22(tInputBuffer, 1, inCoefficients, tOutputBuffer, 1, inNumberFrames);
    
    // Copy the data
    memcpy(ioBuffer, tOutputBuffer + 2, inNumberFrames * sizeof(float));
    memcpy(ioInputBufferInitialValue, &(tInputBuffer[inNumberFrames]), 2 * sizeof(float));
    memcpy(ioOutputBufferInitialValue, &(tOutputBuffer[inNumberFrames]), 2 * sizeof(float));
    
    return noErr;
}

@interface ProcessedAudioPlayer () {
    FilterState filterState;
}

@property (strong, nonatomic) AVPlayer *player;

@end

@implementation ProcessedAudioPlayer

#pragma  mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _filterEnabled = true;
        _filterCornerFrequency = 1000.0;
        
        // Setup FilterState struct
        for (int i = 0; i < NUM_CHANNELS; i++) {
            filterState.gInputKeepBuffer[i] = (float *)calloc(2, sizeof(float));
            filterState.gOutputKeepBuffer[i] = (float *)calloc(2, sizeof(float));
        }
        [self updateFilterCoeffs];
        filterState.gain = 0.5;
    }
    
    return self;
}

- (void)dealloc {
    for (int i = 0; i < NUM_CHANNELS; i++) {
        free(filterState.gInputKeepBuffer[i]);
        free(filterState.gOutputKeepBuffer[i]);
    }
}

#pragma  mark - Setters/Getters

- (void)setVolumeGain:(float)volumeGain {
    filterState.gain = volumeGain;
}

- (float)volumeGain {
    return filterState.gain;
}

- (void)setFilterEnabled:(BOOL)filterEnabled {
    if (_filterEnabled != filterEnabled) {
        _filterEnabled = filterEnabled;
        [self updateFilterCoeffs];
    }
}

- (void)setFilterCornerFrequency:(float)filterCornerFrequency {
    if (_filterCornerFrequency != filterCornerFrequency) {
        _filterCornerFrequency = filterCornerFrequency;
        [self updateFilterCoeffs];
    }
}

- (void)setAssetURL:(NSURL *)assetURL {
    if (_assetURL != assetURL) {
        _assetURL = assetURL;
        
        [self.player pause];
        
        // Create the AVAsset
        AVAsset *asset = [AVAsset assetWithURL:_assetURL];
        assert(asset);
        
        // Create the AVPlayerItem
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
        assert(playerItem);
        
        assert([asset tracks]);
        assert([[asset tracks] count]);
        
        AVAssetTrack *audioTrack = [[asset tracks] objectAtIndex:0];
        AVMutableAudioMixInputParameters *inputParams = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrack];
        
        // Create a processing tap for the input parameters
        MTAudioProcessingTapCallbacks callbacks;
        callbacks.version = kMTAudioProcessingTapCallbacksVersion_0;
        callbacks.clientInfo = &filterState;
        callbacks.init = init;
        callbacks.prepare = prepare;
        callbacks.process = process;
        callbacks.unprepare = unprepare;
        callbacks.finalize = finalize;
        
        MTAudioProcessingTapRef tap;
        // The create function makes a copy of our callbacks struct
        OSStatus err = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks,
                                                  kMTAudioProcessingTapCreationFlag_PostEffects, &tap);
        if (err || !tap) {
            NSLog(@"Unable to create the Audio Processing Tap");
            return;
        }
        assert(tap);
        
        // Assign the tap to the input parameters
        inputParams.audioTapProcessor = tap;
        
        // Create a new AVAudioMix and assign it to our AVPlayerItem
        AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
        audioMix.inputParameters = @[inputParams];
        playerItem.audioMix = audioMix;
        
        self.player = [AVPlayer playerWithPlayerItem:playerItem];
        assert(self.player);
        
        [self.player play];
    }
}

#pragma  mark - Utilities

- (void)updateFilterCoeffs {
    float a0, b0, b1, b2, a1, a2;
    if (self.filterEnabled) {
        float Fc = self.filterCornerFrequency;
        float Q = 0.7071;
        float samplingRate = 44100.0;
        float omega, omegaS, omegaC, alpha;
        
        omega = 2*M_PI*Fc/samplingRate;
        omegaS = sin(omega);
        omegaC = cos(omega);
        alpha = omegaS / (2*Q);
        
        a0 = 1 + alpha;
        b0 = ((1 - omegaC)/2);
        b1 = ((1 - omegaC));
        b2 = ((1 - omegaC)/2);
        a1 = (-2 * omegaC);
        a2 = (1 - alpha);
    } else {
        a0 = 1.0;
        b0 = 1.0;
        b1 = 0.0;
        b2 = 0.0;
        a1 = 0.0;
        a2 = 0.0;
    }
    
    filterState.coefficients[0] = b0/a0;
    filterState.coefficients[1] = b1/a0;
    filterState.coefficients[2] = b2/a0;
    filterState.coefficients[3] = a1/a0;
    filterState.coefficients[4] = a2/a0;
}

#pragma mark MTAudioProcessingTap Callbacks

void init(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut)
{
    NSLog(@"Initialising the Audio Tap Processor");
    *tapStorageOut = clientInfo;
}

void finalize(MTAudioProcessingTapRef tap)
{
    NSLog(@"Finalizing the Audio Tap Processor");
}

void prepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat)
{
    NSLog(@"Preparing the Audio Tap Processor");
    
    UInt32 format4cc = CFSwapInt32HostToBig(processingFormat->mFormatID);
    
    NSLog(@"Sample Rate: %f", processingFormat->mSampleRate);
    NSLog(@"Channels: %u", (unsigned int)processingFormat->mChannelsPerFrame);
    NSLog(@"Bits: %u", (unsigned int)processingFormat->mBitsPerChannel);
    NSLog(@"BytesPerFrame: %u", (unsigned int)processingFormat->mBytesPerFrame);
    NSLog(@"BytesPerPacket: %u", (unsigned int)processingFormat->mBytesPerPacket);
    NSLog(@"FramesPerPacket: %u", (unsigned int)processingFormat->mFramesPerPacket);
    NSLog(@"Format Flags: %d", (unsigned int)processingFormat->mFormatFlags);
    NSLog(@"Format Flags: %4.4s", (char *)&format4cc);
    
    // Looks like this is returning 44.1KHz LPCM @ 32 bit float, packed, non-interleaved
}

void process(MTAudioProcessingTapRef tap, CMItemCount numberFrames,
             MTAudioProcessingTapFlags flags, AudioBufferList *bufferListInOut,
             CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut)
{
    // Alternatively, numberFrames ==
    // UInt32 numFrames = bufferListInOut->mBuffers[LAKE_RIGHT_CHANNEL].mDataByteSize / sizeof(float);
    
    CheckError(MTAudioProcessingTapGetSourceAudio(tap,
                                                  numberFrames,
                                                  bufferListInOut,
                                                  flagsOut,
                                                  NULL,
                                                  numberFramesOut), "GetSourceAudio failed");
    
    FilterState *filterState = (FilterState *) MTAudioProcessingTapGetStorage(tap);
    
    float scalar = filterState->gain;
    
    vDSP_vsmul(bufferListInOut->mBuffers[CHANNEL_RIGHT].mData,
               1,
               &scalar,
               bufferListInOut->mBuffers[CHANNEL_RIGHT].mData,
               1,
               numberFrames);
    vDSP_vsmul(bufferListInOut->mBuffers[CHANNEL_LEFT].mData,
               1,
               &scalar,
               bufferListInOut->mBuffers[CHANNEL_LEFT].mData,
               1,
               numberFrames);
    
    CheckError(BiquadFilter(filterState->coefficients,
                            filterState->gInputKeepBuffer[1],//self.gInputKeepBuffer1,
                            filterState->gOutputKeepBuffer[1],//self.gOutputKeepBuffer1,
                            numberFrames,
                            bufferListInOut->mBuffers[CHANNEL_RIGHT].mData), "Couldn't process Right channel");
    
    CheckError(BiquadFilter(filterState->coefficients,
                            filterState->gInputKeepBuffer[0],//self.gInputKeepBuffer0,
                            filterState->gOutputKeepBuffer[0],//self.gOutputKeepBuffer0,
                            numberFrames,
                            bufferListInOut->mBuffers[CHANNEL_LEFT].mData), "Couldn't process Left channel");
}

void unprepare(MTAudioProcessingTapRef tap)
{
    NSLog(@"Unpreparing the Audio Tap Processor");
}

@end
