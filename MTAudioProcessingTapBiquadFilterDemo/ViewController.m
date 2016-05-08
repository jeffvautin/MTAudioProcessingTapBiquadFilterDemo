//
//  ViewController.m
//  MTAudioProcessingTapBiquadFilterDemo
//
//  Created by Jeff Vautin on 5/7/16.
//  Copyright © 2016 Jeff Vautin. All rights reserved.
//

#import "ViewController.h"
@import MediaPlayer;
#import "ProcessedAudioPlayer.h"

@interface ViewController () <MPMediaPickerControllerDelegate>

@property (strong, nonatomic) ProcessedAudioPlayer *player;
@property (weak, nonatomic) IBOutlet UISlider *volSlider;
@property (weak, nonatomic) IBOutlet UISwitch *filterSwitch;
@property (weak, nonatomic) IBOutlet UISlider *filterSlider;

@end

@implementation ViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        _player = [[ProcessedAudioPlayer alloc] init];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self volSliderChanged:nil];
    [self switchChanged:nil];
    [self filterSliderChanged:nil];
}

- (IBAction)switchChanged:(id)sender {
    self.player.filterEnabled = self.filterSwitch.on;
}

- (IBAction)filterSliderChanged:(id)sender {
    self.player.filterCornerFrequency = self.filterSlider.value;
}

- (IBAction)volSliderChanged:(id)sender {
    self.player.volumeGain = self.volSlider.value;
}

- (IBAction)showMusicPicker:(id)sender {
    MPMediaPickerController *mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio];
    mediaPicker.showsCloudItems = NO;
    mediaPicker.delegate = self;
    
    [self presentViewController:mediaPicker animated:YES completion:nil];
}

- (void)startMusic:(NSURL *)assetURL {
    
    if (!assetURL) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Not Available"
                                                                       message:@"Media not available in library"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:dismissAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
    
    self.player.assetURL = assetURL;
}

#pragma mark MPMediaPickerControllerDelegate

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
    [self dismissViewControllerAnimated:YES completion:nil];
    MPMediaItem *item = mediaItemCollection.items.firstObject;
    if (![[item valueForProperty:MPMediaItemPropertyIsCloudItem] boolValue] && item) {
        NSLog(@"MPMediaItem: %@",item);
        
        NSURL* url = [item valueForProperty:MPMediaItemPropertyAssetURL];
        [self startMusic:url];
    }
}

@end
