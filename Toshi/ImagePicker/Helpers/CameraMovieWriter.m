#import "CameraMovieWriter.h"

#import <SSignalKit/SSignalKit.h>
#import "ImageUtils.h"
#import "PhotoEditorUtils.h"

#import <AVFoundation/AVFoundation.h>

#import "Common.h"

@interface CameraMovieWriter ()
{
    AVAssetWriter *_assetWriter;
    AVAssetWriterInput *_videoInput;
    AVAssetWriterInput *_audioInput;

    bool _startedWriting;
    bool _finishedWriting;
    
    CGAffineTransform _videoTransform;
    NSDictionary *_videoOutputSettings;
    NSDictionary *_audioOutputSettings;
    
    CMTime _startTimeStamp;
    CMTime _lastVideoTimeStamp;
    CMTime _lastAudioTimeStamp;
    
    NSMutableArray *_delayedAudioSamples;
    
    NSTimeInterval _captureStartTime;
    SQueue *_queue;
    
    bool _stopIminent;
    void (^_finishCompletion)(void);
}
@end

@implementation CameraMovieWriter

- (instancetype)initWithVideoTransform:(CGAffineTransform)videoTransform videoOutputSettings:(NSDictionary *)videoSettings audioOutputSettings:(NSDictionary *)audioSettings
{
    self = [super init];
    if (self != nil)
    {
        _videoTransform = videoTransform;
        _videoOutputSettings = videoSettings;
        _audioOutputSettings = audioSettings;
        
        _queue = [[SQueue alloc] init];
        
        _delayedAudioSamples = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)startRecording
{
    [_queue dispatch:^
    {
        if (_isRecording || _finishedWriting)
            return;
        
        _captureStartTime = CFAbsoluteTimeGetCurrent();
        
        NSError *error = nil;
        
        NSString *path = [CameraMovieWriter tempOutputPath];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        
        _assetWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path] fileType:[CameraMovieWriter outputFileType] error:&error];

        if (_assetWriter == nil && error != nil)
        {
            TGLog(@"ERROR: camera movie writer failed to initialize: %@", error);
            return;
        }
        
        _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:_videoOutputSettings];
        _videoInput.expectsMediaDataInRealTime = true;
        _videoInput.transform = _videoTransform;
        
        if ([_assetWriter canAddInput:_videoInput])
        {
            [_assetWriter addInput:_videoInput];
        }
        else
        {
            TGLog(@"ERROR: camera movie writer failed to add video input");
            return;
        }
        
        if (_audioOutputSettings != nil)
        {
            _audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:_audioOutputSettings];
            _audioInput.expectsMediaDataInRealTime = true;
            if ([_assetWriter canAddInput:_audioInput])
            {
                [_assetWriter addInput:_audioInput];
            }
            else
            {
                TGLog(@"ERROR: camera movie writer failed to add audio input");
                return;
            }
        }
        
        [_assetWriter startWriting];
        _isRecording = true;
    }];
}

- (void)stopRecordingWithCompletion:(void (^)(void))completion
{
    [_queue dispatch:^
    {
        if (fabs(CFAbsoluteTimeGetCurrent() - _captureStartTime) < 0.5)
            return;
        
        _stopIminent = true;
        _finishCompletion = completion;
        
        if (_assetWriter.status == AVAssetWriterStatusUnknown || _assetWriter.status > AVAssetWriterStatusCompleted)
        {
            DispatchOnMainThread(^
            {
                if (self.finishedWithMovieAtURL != nil)
                    self.finishedWithMovieAtURL(nil, CGAffineTransformIdentity, CGSizeZero, 0.0, false);
                TGLog(@"ERROR: camera movie writer failed to write movie: %@", _assetWriter.error);
                
                _assetWriter = nil;
            });
            
            return;
        }
        
        if (_audioOutputSettings == nil)
            [self _finishWithCompletion];
    }];
}

- (void)_finishWithCompletion
{
    _isRecording = false;
    
    __weak CameraMovieWriter *weakSelf = self;
    [_assetWriter finishWritingWithCompletionHandler:^
    {
        __strong CameraMovieWriter *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_finishedWriting = true;
        
        DispatchOnMainThread(^
        {
            if (strongSelf->_assetWriter.status == AVAssetWriterStatusCompleted)
            {
                if (strongSelf.finishedWithMovieAtURL != nil)
                {
                    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:strongSelf->_assetWriter.outputURL options:nil];
                    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
                    CGSize dimensions = TGTransformDimensionsWithTransform(track.naturalSize, strongSelf->_videoTransform);
                    strongSelf.finishedWithMovieAtURL(strongSelf->_assetWriter.outputURL, strongSelf->_videoTransform, dimensions, strongSelf.currentDuration, true);
                }
            }
            else
            {
                if (strongSelf.finishedWithMovieAtURL != nil)
                    strongSelf.finishedWithMovieAtURL(strongSelf->_assetWriter.outputURL, CGAffineTransformIdentity, CGSizeZero, 0.0, false);
                TGLog(@"ERROR: camera movie writer failed to write movie: %@", strongSelf->_assetWriter.error);
            }
            
            strongSelf->_assetWriter = nil;
            
            if (_finishCompletion != nil)
                _finishCompletion();
        });
    }];

}

- (void)_processSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CFRetain(sampleBuffer);
    [_queue dispatch:^
    {
        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
        CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
        CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        
        if (_assetWriter.status > AVAssetWriterStatusCompleted)
        {
            TGLog(@"WARNING: camera movie writer status is %d", _assetWriter.status);
            if (_assetWriter.status == AVAssetWriterStatusFailed)
            {
                TGLog(@"ERROR: camera movie writer error: %@", _assetWriter.error);
                _isRecording = false;
                
                if (self.finishedWithMovieAtURL != nil)
                    self.finishedWithMovieAtURL(_assetWriter.outputURL, CGAffineTransformIdentity, CGSizeZero, 0.0, false);
            }
            return;
        }

        bool keepSample = false;
        if (mediaType == kCMMediaType_Video)
        {
            if (!_startedWriting)
            {
                [_assetWriter startSessionAtSourceTime:timestamp];
                _startTimeStamp = timestamp;

                _startedWriting = true;
            }
            
            while (!_videoInput.readyForMoreMediaData)
            {
                NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
                [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
            }

            bool success = [_videoInput appendSampleBuffer:sampleBuffer];
            if (success)
                _lastVideoTimeStamp = timestamp;
            else
                TGLog(@"ERROR: camera movie writer failed to append pixel buffer");
            
            if (_audioOutputSettings != nil && _stopIminent && CMTimeCompare(_lastVideoTimeStamp, _lastAudioTimeStamp) != -1) {
                [self _finishWithCompletion];
            }
        }
        else if (mediaType == kCMMediaType_Audio && !_stopIminent)
        {
            if (!_startedWriting)
            {
                [_delayedAudioSamples addObject:(__bridge id _Nonnull)(sampleBuffer)];
                keepSample = true;
            }
            else
            {
                if (_delayedAudioSamples.count > 0)
                {
                    for (id sample in _delayedAudioSamples)
                    {
                        CMSampleBufferRef buffer = (__bridge CMSampleBufferRef)(sample);
                        [_audioInput appendSampleBuffer:buffer];
                        CFRelease(buffer);
                    }
                    
                    _delayedAudioSamples = nil;
                }
                
                while (!_audioInput.isReadyForMoreMediaData)
                {
                    NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
                    [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
                }
            
                bool success = [_audioInput appendSampleBuffer:sampleBuffer];
                if (success)
                    _lastAudioTimeStamp = timestamp;
                else
                    TGLog(@"ERROR: camera movie writer failed to append audio buffer");
            }
        }
        
        if (!keepSample)
            CFRelease(sampleBuffer);
    }];
}

- (NSTimeInterval)currentDuration
{
    return CMTimeGetSeconds(CMTimeSubtract(_lastVideoTimeStamp, _startTimeStamp));
}

+ (NSString *)outputFileType
{
    return AVFileTypeMPEG4;
}

+ (NSString *)tempOutputPath
{
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"cam_%x.mp4", (int)arc4random()]];
}

@end
