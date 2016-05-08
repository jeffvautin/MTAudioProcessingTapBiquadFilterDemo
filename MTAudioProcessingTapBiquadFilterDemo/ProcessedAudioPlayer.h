//
//  processedAudioPlayer.h
//  mtaudioprocessingtapTestObjC
//
//  Created by Jeff Vautin on 5/7/16.
//  Copyright © 2016 Jeff Vautin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ProcessedAudioPlayer : NSObject

@property (strong, nonatomic) NSURL *assetURL;
@property (nonatomic) BOOL filterEnabled;
@property (nonatomic) float filterCornerFrequency;
@property (nonatomic) float volumeGain;

@end
