//
//  AppDelegate.m
//  Gifzo
//

#import "AppDelegate.h"
#import "BorderlessWindow.h"

@implementation AppDelegate {
  NSMutableArray *_windows;
  BOOL _isRecording, _recordingDidFinished;
  NSURL *_tempURL;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  self.recorder = [[Recorder alloc] init];
  self.recorder.delegate = self;
  _isRecording = NO;
  
  // movファイル書き出し用のテンポラリディレクトリの初期化
  NSString *tempName = [self generateTempName];
  _tempURL = [NSURL fileURLWithPath:[tempName stringByAppendingPathExtension:@"mov"]];
  
  [self startCropRect];
}

- (void)startRecording:(NSRect)cropRect screen:(NSScreen *)screen
{
  [self.recorder startRecordingWithOutputURL:_tempURL croppingRect:cropRect screen:screen];
  
  _isRecording = YES;
}

#define kShadyWindowLevel   (NSScreenSaverWindowLevel + 1)

- (void)startCropRect
{
  _windows = [NSMutableArray array];
  
  for (NSScreen *screen in [NSScreen screens]) {
    NSRect frame = [screen frame];
    NSWindow *window = [[BorderlessWindow alloc] initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    [window setBackgroundColor:[NSColor clearColor]];
    [window setOpaque:NO];
    [window setLevel:kShadyWindowLevel];
    [window setReleasedWhenClosed:YES];
    
    DrawMouseBoxView *drawMouseBoxView = [[DrawMouseBoxView alloc] initWithFrame:frame];
    drawMouseBoxView.screen = screen;
    drawMouseBoxView.delegate = self;
    
    [window setContentView:drawMouseBoxView];
    [window makeKeyAndOrderFront:self];
    [_windows addObject:window];
  }
}

#pragma mark - DrawMouseBoxViewDelegate

- (void)startRecordingKeyDidPressedInView:(DrawMouseBoxView *)view withRect:(NSRect)rect screen:(NSScreen *)screen
{
  if (_recordingDidFinished) return;
  
  if (_isRecording) {
    [self.recorder finishRecording];
    _recordingDidFinished = YES;
  } else {
    [self startRecording:rect screen:screen];
  }
}

#pragma mark - RecorderDelegate

- (void)recorder:(Recorder *)recorder didRecordedWithOutputURL:(NSURL *)outputFileURL
{
  for (NSWindow *window in _windows) {
    [window close];
  }
  
  [self convertFromMOVToMP4:outputFileURL];
}

- (void)convertFromMOVToMP4:(NSURL *)outputFileURL
{
  AVAsset *asset = [AVAsset assetWithURL:outputFileURL];
  AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetPassthrough];
  
  NSString *tempName = [self generateTempName];
  
  exportSession.outputURL = [NSURL fileURLWithPath:[tempName stringByAppendingPathExtension:@"mp4"]];
  exportSession.outputFileType = AVFileTypeMPEG4;
  
  [exportSession exportAsynchronouslyWithCompletionHandler:^{
    switch ([exportSession status]) {
      case AVAssetExportSessionStatusCompleted:
        NSLog(@"Export completed: %@", exportSession.outputURL);
        // [self upload:exportSession.outputURL];
        [self save:exportSession.outputURL];
        break;
      case AVAssetExportSessionStatusFailed:
        NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);
        break;
      case AVAssetExportSessionStatusCancelled:
        NSLog(@"Export canceled");
        break;
      default:
        break;
    }
    
    [NSApp terminate:nil];
  }];
}

- (NSString *)generateTempName
{
  char *tempNameBytes = tempnam([NSTemporaryDirectory() fileSystemRepresentation], "Gifzo_");
  NSString *tempName = [[NSString alloc] initWithBytesNoCopy:tempNameBytes length:strlen(tempNameBytes) encoding:NSUTF8StringEncoding freeWhenDone:YES];
  
  return tempName;
}

// mp4ファイルを保存する
- (void)save:(NSURL *)videoURL
{
  NSError *error = nil;
  NSURL *url = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingString:@"/Movies/Gifzo"]];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  BOOL isDirectory;
  if (![fileManager fileExistsAtPath:[url path] isDirectory:&isDirectory]) {
    [fileManager createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
      NSLog(@"File Manager Create Directory Error: %@", [error localizedDescription]);
      return;
    }
  }
  url = [url URLByAppendingPathComponent:@"/"];
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"YYYY-MM-dd-hh-mm-ss"];
  NSString *dateString = [formatter stringFromDate:[NSDate date]];
  NSString *filename = [@[@"スクリーンキャプチャ ", dateString, @".mp4"] componentsJoinedByString:@""];
  [fileManager moveItemAtURL:videoURL toURL:[url URLByAppendingPathComponent:filename] error:&error];
  if (error) {
    NSLog(@"File Manager Move Item Error: %@", [error localizedDescription]);
    return;
  }
  NSLog(@"Complte Create Video");
}

// mp4ファイルをmultipart uploadする
- (void)upload:(NSURL *)videoURL
{
  NSUserDefaults *defaults = [self setupUserDefaults];
  
  NSURL *uploadURL = [NSURL URLWithString:[defaults stringForKey:@"url"]];
  
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:uploadURL];
  [request setHTTPMethod:@"POST"];
  
  NSMutableData *body = [NSMutableData data];
  
  NSString *boundary = @"--------------------------298e6779c7a9";
  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
  [request addValue:contentType forHTTPHeaderField:@"Content-Type"];
  
  NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
  
  [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [body appendData:[@"Content-Disposition: form-data; name=\"data\"; filename=\"gifzo.mp4\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  [body appendData:videoData];
  [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  
  [request setHTTPBody:body];
  
  NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
  NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
  
  NSURL *gifURL = [NSURL URLWithString:returnString];
  
  [self copyToPasteboard:returnString];
  
  [[NSWorkspace sharedWorkspace] openURL:gifURL];
}

- (void)copyToPasteboard:(NSString *)urlString
{
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard declareTypes:[NSArray arrayWithObjects:NSPasteboardTypeString, nil] owner:nil];
  [pasteboard setString:urlString forType:NSPasteboardTypeString];
}

- (NSUserDefaults *)setupUserDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
  NSDictionary *initialValueDict = @{
                                     @"url" : @"http://gifzo.net/"
                                     };
  
  [defaults registerDefaults:initialValueDict];
  
  return defaults;
}
@end
