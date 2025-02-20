#import "Camera.h"
#import "CameraCaptureSession.h"
#import "CameraMovieWriter.h"
#import "CameraDeviceAngleSampler.h"

#import "SQueue.h"

#import "AccessChecker.h"
#import "CameraPreviewView.h"

#import "Common.h"

NSString *const PGCameraFlashActiveKey = @"flashActive";
NSString *const PGCameraFlashAvailableKey = @"flashAvailable";
NSString *const PGCameraTorchActiveKey = @"torchActive";
NSString *const PGCameraTorchAvailableKey = @"torchAvailable";
NSString *const PGCameraAdjustingFocusKey = @"adjustingFocus";

@interface Camera ()
{
    dispatch_queue_t cameraProcessingQueue;
    dispatch_queue_t audioProcessingQueue;
    
    AVCaptureDevice *_microphone;
    AVCaptureVideoDataOutput *videoOutput;
    AVCaptureAudioDataOutput *audioOutput;
    
    CameraDeviceAngleSampler *_deviceAngleSampler;
    
    bool _subscribedForCameraChanges;
    
    bool _shownAudioAccessDisabled;
    
    bool _invalidated;
    bool _wasCapturingOnEnterBackground;
    
    bool _capturing;
    bool _moment;
    
    CameraPreviewView *_previewView;
    
    NSTimeInterval _captureStartTime;
}
@end

@implementation Camera

- (instancetype)init
{
    return [self initWithMode:PGCameraModePhoto position:PGCameraPositionUndefined];
}

- (instancetype)initWithMode:(PGCameraMode)mode position:(PGCameraPosition)position
{
    self = [super init];
    if (self != nil)
    {
        _captureSession = [[CameraCaptureSession alloc] initWithMode:mode position:position];
        _deviceAngleSampler = [[CameraDeviceAngleSampler alloc] init];
        [_deviceAngleSampler startMeasuring];
        
        __weak Camera *weakSelf = self;
        self.captureSession.requestPreviewIsMirrored = ^bool
        {
            __strong Camera *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf->_previewView == nil)
                return false;
            
            CameraPreviewView *previewView = strongSelf->_previewView;
            return previewView.captureConnection.videoMirrored;
        };
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleEnteredBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleEnteredForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    TGLog(@"Camera: dealloc");
    [_deviceAngleSampler stopMeasuring];
    [self _unsubscribeFromCameraChanges];
    
    self.captureSession.requestPreviewIsMirrored = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionRuntimeErrorNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:nil];
}

- (void)handleEnteredBackground:(NSNotification *)__unused notification
{
    if (self.isCapturing)
        _wasCapturingOnEnterBackground = true;
    
    [self stopCaptureForPause:true completion:nil];
}

- (void)handleEnteredForeground:(NSNotification *)__unused notification
{
    if (_wasCapturingOnEnterBackground)
    {
        _wasCapturingOnEnterBackground = false;
        [self startCaptureForResume:true completion:nil];
    }
}

- (void)handleRuntimeError:(NSNotification *)notification
{
    TGLog(@"ERROR: Camera runtime error: %@", notification.userInfo[AVCaptureSessionErrorKey]);

    __weak Camera *weakSelf = self;
    DispatchAfter(1.5f, [Camera cameraQueue]._dispatch_queue, ^
    {
        __strong Camera *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_invalidated)
            return;
        
        [strongSelf _unsubscribeFromCameraChanges];
        
        for (AVCaptureInput *input in strongSelf.captureSession.inputs)
            [strongSelf.captureSession removeInput:input];
        for (AVCaptureOutput *output in strongSelf.captureSession.outputs)
            [strongSelf.captureSession removeOutput:output];
        
        [strongSelf.captureSession performInitialConfigurationWithCompletion:^
        {
            __strong Camera *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf _subscribeForCameraChanges];
        }];
    });
}

- (void)handleInterrupted:(NSNotification *)notification
{
    if (iosMajorVersion() < 9)
        return;
    
    AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
    TGLog(@"WARNING: Camera was interrupted with reason %d", reason);
    if (self.captureInterrupted != nil)
        self.captureInterrupted(reason);
}

- (void)_subscribeForCameraChanges
{
    if (_subscribedForCameraChanges)
        return;
    
    _subscribedForCameraChanges = true;
    
    [self.captureSession.videoDevice addObserver:self forKeyPath:PGCameraFlashActiveKey options:NSKeyValueObservingOptionNew context:NULL];
    [self.captureSession.videoDevice addObserver:self forKeyPath:PGCameraFlashAvailableKey options:NSKeyValueObservingOptionNew context:NULL];
    [self.captureSession.videoDevice addObserver:self forKeyPath:PGCameraTorchActiveKey options:NSKeyValueObservingOptionNew context:NULL];
    [self.captureSession.videoDevice addObserver:self forKeyPath:PGCameraTorchAvailableKey options:NSKeyValueObservingOptionNew context:NULL];
    [self.captureSession.videoDevice addObserver:self forKeyPath:PGCameraAdjustingFocusKey options:NSKeyValueObservingOptionNew context:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaChanged:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.captureSession.videoDevice];
}

- (void)_unsubscribeFromCameraChanges
{
    if (!_subscribedForCameraChanges)
        return;
    
    _subscribedForCameraChanges = false;
    
    @try {
        [self.captureSession.videoDevice removeObserver:self forKeyPath:PGCameraFlashActiveKey];
        [self.captureSession.videoDevice removeObserver:self forKeyPath:PGCameraFlashAvailableKey];
        [self.captureSession.videoDevice removeObserver:self forKeyPath:PGCameraTorchActiveKey];
        [self.captureSession.videoDevice removeObserver:self forKeyPath:PGCameraTorchAvailableKey];
        [self.captureSession.videoDevice removeObserver:self forKeyPath:PGCameraAdjustingFocusKey];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.captureSession.videoDevice];
    } @catch(NSException *e) { }
}

- (void)attachPreviewView:(CameraPreviewView *)previewView
{
    CameraPreviewView *currentPreviewView = _previewView;
    if (currentPreviewView != nil)
        [currentPreviewView invalidate];
    
    _previewView = previewView;
    [previewView setupWithCamera:self];

    __weak Camera *weakSelf = self;
    [[Camera cameraQueue] dispatch:^
    {
        __strong Camera *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_invalidated)
            return;

        [strongSelf.captureSession performInitialConfigurationWithCompletion:^
        {
            __strong Camera *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf _subscribeForCameraChanges];
        }];
    }];
}

#pragma mark -

- (bool)isCapturing
{
    return _capturing;
}

- (void)startCaptureForResume:(bool)resume completion:(void (^)(void))completion
{
    if (_invalidated)
        return;
    
    [[Camera cameraQueue] dispatch:^
    {
        if (self.captureSession.isRunning)
            return;
        
        _capturing = true;
        
        TGLog(@"Camera: start capture");
#if !TARGET_IPHONE_SIMULATOR
        [self.captureSession startRunning];
#endif
        
        if (_captureStartTime < FLT_EPSILON)
            _captureStartTime = CFAbsoluteTimeGetCurrent();

        DispatchOnMainThread(^
        {
            if (self.captureStarted != nil)
                self.captureStarted(resume);
            
            if (completion != nil)
                completion();
        });
    }];
}

- (void)stopCaptureForPause:(bool)pause completion:(void (^)(void))completion
{
    if (_invalidated)
        return;
    
    if (!pause)
        _invalidated = true;
    
    TGLog(@"Camera: stop capture");
    
    [[Camera cameraQueue] dispatch:^
    {
        if (_invalidated)
        {
            [self.captureSession beginConfiguration];
            
            [self.captureSession resetFlashMode];
            
            TGLog(@"Camera: stop capture invalidated");
            CameraPreviewView *previewView = _previewView;
            if (previewView != nil)
                [previewView invalidate];
            
            for (AVCaptureInput *input in self.captureSession.inputs)
                [self.captureSession removeInput:input];
            for (AVCaptureOutput *output in self.captureSession.outputs)
                [self.captureSession removeOutput:output];
            
#if !TARGET_IPHONE_SIMULATOR
            [self.captureSession commitConfiguration];
#endif
        }
        
        TGLog(@"Camera: stop running");
#if !TARGET_IPHONE_SIMULATOR
        [self.captureSession stopRunning];
#endif
        
        _capturing = false;
        
        DispatchOnMainThread(^
        {
            if (_invalidated)
                _previewView = nil;
            
            if (self.captureStopped != nil)
                self.captureStopped(pause);
        });
        
        if (completion != nil)
            completion();
    }];
}

- (bool)isResetNeeded
{
    return self.captureSession.isResetNeeded;
}

- (void)resetSynchronous:(bool)synchronous completion:(void (^)(void))completion
{
    [self resetTerminal:false synchronous:synchronous completion:completion];
}

- (void)resetTerminal:(bool)__unused terminal synchronous:(bool)synchronous completion:(void (^)(void))completion
{
    void (^block)(void) = ^
    {
        [self _unsubscribeFromCameraChanges];
        [self.captureSession reset];
        [self _subscribeForCameraChanges];
        
        if (completion != nil)
            completion();
    };
    
    if (synchronous)
        [[Camera cameraQueue] dispatchSync:block];
    else
        [[Camera cameraQueue] dispatch:block];
}

#pragma mark - 

- (void)captureNextFrameCompletion:(void (^)(UIImage * image))completion
{
    [self.captureSession captureNextFrameCompletion:completion];
}

- (void)takePhotoWithCompletion:(void (^)(UIImage *result, CameraShotMetadata *metadata))completion
{
    [[Camera cameraQueue] dispatch:^
    {
        if (!self.captureSession.isRunning || self.captureSession.imageOutput.isCapturingStillImage || _invalidated)
            return;
        
        void (^takePhoto)(void) = ^
        {
            CameraPreviewView *previewView = _previewView;
            AVCaptureConnection *previewConnection = previewView.captureConnection;
            AVCaptureConnection *imageConnection = [self.captureSession.imageOutput connectionWithMediaType:AVMediaTypeVideo];
            [imageConnection setVideoMirrored:previewConnection.videoMirrored];
            
            bool isMirrored = previewConnection.videoMirrored;
            UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
            if (self.requestedCurrentInterfaceOrientation != nil)
                orientation = self.requestedCurrentInterfaceOrientation(NULL);
            
            [imageConnection setVideoOrientation:[Camera _videoOrientationForInterfaceOrientation:orientation mirrored:false]];
            
            [self.captureSession.imageOutput captureStillImageAsynchronouslyFromConnection:self.captureSession.imageOutput.connections.firstObject completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error)
            {
                if (imageDataSampleBuffer != NULL && error == nil)
                {
                    NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                    UIImage *image = [[UIImage alloc] initWithData:imageData];
                    
                    if (self.cameraMode == PGCameraModeSquare)
                    {
                        CGFloat shorterSide = MIN(image.size.width, image.size.height);
                        CGFloat longerSide = MAX(image.size.width, image.size.height);
                        
                        CGRect cropRect = CGRectMake(floor((longerSide - shorterSide) / 2.0f), 0, shorterSide, shorterSide);
                        CGImageRef croppedCGImage = CGImageCreateWithImageInRect(image.CGImage, cropRect);
                        image = [UIImage imageWithCGImage:croppedCGImage scale:image.scale orientation:image.imageOrientation];
                        CGImageRelease(croppedCGImage);
                    }
                    
                    CameraShotMetadata *metadata = [[CameraShotMetadata alloc] init];
                    metadata.frontal = isMirrored;
                    metadata.deviceAngle = [CameraShotMetadata relativeDeviceAngleFromAngle:_deviceAngleSampler.currentDeviceAngle orientation:orientation];
                    
                    if (completion != nil)
                        completion(image, metadata);
                }
            }];
        };
        
        NSTimeInterval delta = CFAbsoluteTimeGetCurrent() - _captureStartTime;
        if (CFAbsoluteTimeGetCurrent() - _captureStartTime > 0.4)
            takePhoto();
        else
            DispatchAfter(0.4 - delta, [[Camera cameraQueue] _dispatch_queue], takePhoto);
    }];
}

- (void)startVideoRecordingForMoment:(bool)moment completion:(void (^)(NSURL *, CGAffineTransform transform, CGSize dimensions, NSTimeInterval duration, bool success))completion
{
    [[Camera cameraQueue] dispatch:^
    {
        if (!self.captureSession.isRunning || _invalidated)
            return;
        
        void (^startRecording)(void) = ^
        {
            UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
            bool mirrored = false;
            
            if (self.requestedCurrentInterfaceOrientation != nil)
                orientation = self.requestedCurrentInterfaceOrientation(&mirrored);
            
            _moment = moment;
            
            [self.captureSession startVideoRecordingWithOrientation:[Camera _videoOrientationForInterfaceOrientation:orientation mirrored:mirrored] mirrored:mirrored completion:completion];
            
            DispatchOnMainThread(^
            {
                if (self.reallyBeganVideoRecording != nil)
                    self.reallyBeganVideoRecording(moment);
            });
        };
        
        NSTimeInterval delta = CFAbsoluteTimeGetCurrent() - _captureStartTime;
        if (CFAbsoluteTimeGetCurrent() - _captureStartTime > 0.8)
            startRecording();
        else
            DispatchAfter(0.8 - delta, [[Camera cameraQueue] _dispatch_queue], startRecording);
        
        DispatchOnMainThread(^
        {
            if (self.beganVideoRecording != nil)
                self.beganVideoRecording(moment);
        });
    }];
}

- (void)stopVideoRecording
{
    [[Camera cameraQueue] dispatch:^
    {
        [self.captureSession stopVideoRecording];
        
        DispatchOnMainThread(^
        {
            if (self.finishedVideoRecording != nil)
                self.finishedVideoRecording(_moment);
        });
    }];
}

- (bool)isRecordingVideo
{
    return self.captureSession.movieWriter.isRecording;
}

- (NSTimeInterval)videoRecordingDuration
{
    return self.captureSession.movieWriter.currentDuration;
}

#pragma mark - Mode

- (PGCameraMode)cameraMode
{
    return self.captureSession.currentMode;
}

- (void)setCameraMode:(PGCameraMode)cameraMode
{
    if (self.disabled || self.captureSession.currentMode == cameraMode)
        return;
    
    __weak Camera *weakSelf = self;
    void(^commitBlock)(void) = ^
    {
        __strong Camera *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [[Camera cameraQueue] dispatch:^
        {
            strongSelf.captureSession.currentMode = cameraMode;
             
            if (strongSelf.finishedModeChange != nil)
                strongSelf.finishedModeChange();
            
            if (strongSelf.autoStartVideoRecording && strongSelf.onAutoStartVideoRecording != nil)
            {
                DispatchAfter(0.5, dispatch_get_main_queue(), ^
                {
                    strongSelf.onAutoStartVideoRecording();                    
                });
            }
            
            strongSelf.autoStartVideoRecording = false;
        }];
    };
    
    if (self.beganModeChange != nil)
        self.beganModeChange(cameraMode, commitBlock);
}

#pragma mark - Focus and Exposure

- (void)subjectAreaChanged:(NSNotification *)__unused notification
{
    [self resetFocusPoint];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)__unused object change:(NSDictionary *)__unused change context:(void *)__unused context
{
    DispatchOnMainThread(^
    {
        if ([keyPath isEqualToString:PGCameraAdjustingFocusKey])
        {
            bool adjustingFocus = [[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:@YES];
            
            if (adjustingFocus && self.beganAdjustingFocus != nil)
                self.beganAdjustingFocus();
            else if (!adjustingFocus && self.finishedAdjustingFocus != nil)
                self.finishedAdjustingFocus();
        }
        else if ([keyPath isEqualToString:PGCameraFlashActiveKey] || [keyPath isEqualToString:PGCameraTorchActiveKey])
        {
            bool active = [[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:@YES];
            
            if (self.flashActivityChanged != nil)
                self.flashActivityChanged(active);
        }
        else if ([keyPath isEqualToString:PGCameraFlashAvailableKey] || [keyPath isEqualToString:PGCameraTorchAvailableKey])
        {
            bool available = [[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:@YES];
            
            if (self.flashAvailabilityChanged != nil)
                self.flashAvailabilityChanged(available);
        }
    });
}

- (bool)supportsExposurePOI
{
    return [self.captureSession.videoDevice isExposurePointOfInterestSupported];
}

- (bool)supportsFocusPOI
{
    return [self.captureSession.videoDevice isFocusPointOfInterestSupported];
}

- (void)resetFocusPoint
{
    const CGPoint centerPoint = CGPointMake(0.5f, 0.5f);
    [self _setFocusPoint:centerPoint focusMode:AVCaptureFocusModeContinuousAutoFocus exposureMode:AVCaptureExposureModeContinuousAutoExposure monitorSubjectAreaChange:false];
}

- (void)setFocusPoint:(CGPoint)point
{
    [self _setFocusPoint:point focusMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose monitorSubjectAreaChange:true];
}

- (void)_setFocusPoint:(CGPoint)point focusMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode monitorSubjectAreaChange:(bool)monitorSubjectAreaChange
{
    [[Camera cameraQueue] dispatch:^
    {
        if (self.disabled)
            return;
        
        [self.captureSession setFocusPoint:point focusMode:focusMode exposureMode:exposureMode monitorSubjectAreaChange:monitorSubjectAreaChange];
    }];
}

- (bool)supportsExposureTargetBias
{
    return [self.captureSession.videoDevice respondsToSelector:@selector(setExposureTargetBias:completionHandler:)];
}

- (void)beginExposureTargetBiasChange
{
    [[Camera cameraQueue] dispatch:^
    {
        if (self.disabled)
            return;
        
        [self.captureSession setFocusPoint:self.captureSession.focusPoint focusMode:AVCaptureFocusModeLocked exposureMode:AVCaptureExposureModeLocked monitorSubjectAreaChange:false];
    }];
}

- (void)setExposureTargetBias:(CGFloat)bias
{
    [[Camera cameraQueue] dispatch:^
    {
        if (self.disabled)
            return;
        
        [self.captureSession setExposureTargetBias:bias];
    }];
}

- (void)endExposureTargetBiasChange
{
    [[Camera cameraQueue] dispatch:^
    {
        if (self.disabled)
            return;
        
        [self.captureSession setFocusPoint:self.captureSession.focusPoint focusMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose monitorSubjectAreaChange:true];
    }];
}

#pragma mark - Flash

- (bool)hasFlash
{
    return self.captureSession.videoDevice.hasFlash;
}

- (bool)flashActive
{
    if (self.cameraMode == PGCameraModeVideo || self.cameraMode == PGCameraModeClip)
        return self.captureSession.videoDevice.torchActive;
    
    return self.captureSession.videoDevice.flashActive;
}

- (bool)flashAvailable
{
    if (self.cameraMode == PGCameraModeVideo || self.cameraMode == PGCameraModeClip)
        return self.captureSession.videoDevice.torchAvailable;
    
    return self.captureSession.videoDevice.flashAvailable;
}

- (PGCameraFlashMode)flashMode
{
    return self.captureSession.currentFlashMode;
}

- (void)setFlashMode:(PGCameraFlashMode)flashMode
{
    [[Camera cameraQueue] dispatch:^
    {
        self.captureSession.currentFlashMode = flashMode;
    }];
}

#pragma mark - Position

- (PGCameraPosition)togglePosition
{
    if ([AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count < 2 || self.disabled)
        return self.captureSession.currentCameraPosition;
    
    [self _unsubscribeFromCameraChanges];
    
    PGCameraPosition targetCameraPosition = PGCameraPositionFront;
    if (self.captureSession.currentCameraPosition == PGCameraPositionFront)
        targetCameraPosition = PGCameraPositionRear;
    
    AVCaptureDevice *targetDevice = [CameraCaptureSession _deviceWithCameraPosition:targetCameraPosition];
    
    __weak Camera *weakSelf = self;
    void(^commitBlock)(void) = ^
    {
        __strong Camera *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [[Camera cameraQueue] dispatch:^
        {
            [strongSelf.captureSession setCurrentCameraPosition:targetCameraPosition];
             
            if (strongSelf.finishedPositionChange != nil)
                strongSelf.finishedPositionChange();
             
            [strongSelf setZoomLevel:0.0f];
            [strongSelf _subscribeForCameraChanges];
        }];
    };
    
    if (self.beganPositionChange != nil)
        self.beganPositionChange(targetDevice.hasFlash, [CameraCaptureSession _isZoomAvailableForDevice:targetDevice], commitBlock);
    
    return targetCameraPosition;
}

#pragma mark - Zoom

- (bool)isZoomAvailable
{
    return self.captureSession.isZoomAvailable;
}

- (CGFloat)zoomLevel
{
    return self.captureSession.zoomLevel;
}

- (void)setZoomLevel:(CGFloat)zoomLevel
{
    zoomLevel = MAX(0.0f, MIN(1.0f, zoomLevel));
    
    [[Camera cameraQueue] dispatch:^
    {
        if (self.disabled)
            return;
        
        [self.captureSession setZoomLevel:zoomLevel];
    }];
}

#pragma mark - Device Angle

- (void)startDeviceAngleMeasuring
{
    [_deviceAngleSampler startMeasuring];
}

- (void)stopDeviceAngleMeasuring
{
    [_deviceAngleSampler stopMeasuring];
}

#pragma mark - Availability

+ (bool)cameraAvailable
{
#if TARGET_IPHONE_SIMULATOR
    return false;
#endif
    
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

+ (bool)hasRearCamera
{
    return ([CameraCaptureSession _deviceWithCameraPosition:PGCameraPositionRear] != nil);
}

+ (bool)hasFrontCamera
{
    return ([CameraCaptureSession _deviceWithCameraPosition:PGCameraPositionFront] != nil);
}

+ (SQueue *)cameraQueue
{
    static dispatch_once_t onceToken;
    static SQueue *queue = nil;
    dispatch_once(&onceToken, ^
    {
        queue = [[SQueue alloc] init];
    });
    
    return queue;
}

+ (AVCaptureVideoOrientation)_videoOrientationForInterfaceOrientation:(UIInterfaceOrientation)deviceOrientation mirrored:(bool)mirrored
{
    switch (deviceOrientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
            
        case UIInterfaceOrientationLandscapeLeft:
            return mirrored ? AVCaptureVideoOrientationLandscapeRight : AVCaptureVideoOrientationLandscapeLeft;
            
        case UIInterfaceOrientationLandscapeRight:
            return mirrored ? AVCaptureVideoOrientationLandscapeLeft : AVCaptureVideoOrientationLandscapeRight;
            
        default:
            return AVCaptureVideoOrientationPortrait;
    }
}

+ (PGCameraAuthorizationStatus)cameraAuthorizationStatus
{
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)])
        return [Camera _cameraAuthorizationStatusForAuthorizationStatus:[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]];
    
    return PGCameraAuthorizationStatusAuthorized;
}

+ (PGMicrophoneAuthorizationStatus)microphoneAuthorizationStatus
{
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)])
        return [Camera _microphoneAuthorizationStatusForAuthorizationStatus:[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]];
        
    return PGMicrophoneAuthorizationStatusAuthorized;
}

+ (PGCameraAuthorizationStatus)_cameraAuthorizationStatusForAuthorizationStatus:(AVAuthorizationStatus)authorizationStatus
{
    switch (authorizationStatus)
    {
        case AVAuthorizationStatusRestricted:
            return PGCameraAuthorizationStatusRestricted;
            
        case AVAuthorizationStatusDenied:
            return PGCameraAuthorizationStatusDenied;
            
        case AVAuthorizationStatusAuthorized:
            return PGCameraAuthorizationStatusAuthorized;
            
        default:
            return PGCameraAuthorizationStatusNotDetermined;
    }
}

+ (PGMicrophoneAuthorizationStatus)_microphoneAuthorizationStatusForAuthorizationStatus:(AVAuthorizationStatus)authorizationStatus
{
    switch (authorizationStatus)
    {
        case AVAuthorizationStatusRestricted:
            return PGMicrophoneAuthorizationStatusRestricted;
            
        case AVAuthorizationStatusDenied:
            return PGMicrophoneAuthorizationStatusDenied;
            
        case AVAuthorizationStatusAuthorized:
            return PGMicrophoneAuthorizationStatusAuthorized;
            
        default:
            return PGMicrophoneAuthorizationStatusNotDetermined;
    }
}

@end
