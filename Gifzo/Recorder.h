//
//  Recorder.h
//  Gifzo
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class Recorder;

@protocol RecorderDelegate <NSObject>
- (void)recorder:(Recorder *)recorder didRecordedWithOutputURL:(NSURL *)outputFileURL;
@end

@interface Recorder : NSObject <AVCaptureFileOutputRecordingDelegate>
@property(weak) id <RecorderDelegate> delegate;
- (void)startRecordingWithOutputURL:(NSURL *)outputFileURL croppingRect:(NSRect)rect screen:(NSScreen *)screen;
- (void)finishRecording;
@end
