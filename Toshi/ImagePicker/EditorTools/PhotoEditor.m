#import "PhotoEditor.h"

#import "ATQueue.h" //
#import "MemoryImageCache.h"

#import "PhotoEditorUtils.h"
#import "PhotoEditorPreviewView.h" //
#import "PhotoEditorView.h" //
#import "PhotoEditorPicture.h" //

#import "PhotoEditorValues.h" //
#import "VideoEditAdjustments.h" //
#import "PaintingData.h"  //

#import "PhotoToolComposer.h"
#import "EnhanceTool.h"
#import "ExposureTool.h"
#import "ContrastTool.h"
#import "WarmthTool.h"
#import "SaturationTool.h"
#import "HighlightsTool.h"
#import "ShadowsTool.h"
#import "VignetteTool.h"
#import "GrainTool.h"
#import "BlurTool.h"
#import "SharpenTool.h"
#import "FadeTool.h"
#import "TintTool.h"
#import "CurvesTool.h"
#import "Common.h"
#import "PhotoHistogramGenerator.h" // HAVE

@interface PhotoEditor ()
{
    PhotoToolComposer *_toolComposer;
    
    id<MediaEditAdjustments> _initialAdjustments;
    
    PhotoEditorPicture *_currentInput;
    NSArray *_currentProcessChain;
    GPUImageOutput <GPUImageInput> *_finalFilter;
    
    PhotoHistogram *_currentHistogram;
    PhotoHistogramGenerator *_histogramGenerator;
    
    UIImageOrientation _imageCropOrientation;
    CGRect _imageCropRect;
    CGFloat _imageCropRotation;
    bool _imageCropMirrored;
    
    SPipe *_histogramPipe;
    
    ATQueue *_queue;
    
    bool _forVideo;
    
    bool _processing;
    bool _needsReprocessing;
    
    bool _fullSize;
}
@end

@implementation PhotoEditor

- (instancetype)initWithOriginalSize:(CGSize)originalSize adjustments:(id<MediaEditAdjustments>)adjustments forVideo:(bool)forVideo
{
    self = [super init];
    if (self != nil)
    {
        _queue = [[ATQueue alloc] init];
        
        _forVideo = forVideo;
        
        _originalSize = originalSize;
        _cropRect = CGRectMake(0.0f, 0.0f, _originalSize.width, _originalSize.height);
        _paintingData = adjustments.paintingData;
        
        _tools = [self toolsInit];
        _toolComposer = [[PhotoToolComposer alloc] init];
        [_toolComposer addPhotoTools:_tools];
        [_toolComposer compose];

        _histogramPipe = [[SPipe alloc] init];
        
        __weak PhotoEditor *weakSelf = self;
        _histogramGenerator = [[PhotoHistogramGenerator alloc] init];
        _histogramGenerator.histogramReady = ^(PhotoHistogram *histogram)
        {
            __strong PhotoEditor *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            strongSelf->_currentHistogram = histogram;
            strongSelf->_histogramPipe.sink(histogram);
        };
        
        [self _importAdjustments:adjustments];
    }
    return self;
}

- (void)dealloc
{
    DispatchAfter(1.5f, dispatch_get_main_queue(), ^
    {
        [[GPUImageContext sharedFramebufferCache] purgeAllUnassignedFramebuffers];
    });
}

- (void)cleanup
{
    [[GPUImageContext sharedFramebufferCache] purgeAllUnassignedFramebuffers];
}

- (NSArray *)toolsInit
{
    NSMutableArray *tools = [NSMutableArray array];
    for (Class toolClass in [PhotoEditor availableTools])
    {
        PhotoTool *toolInstance = [[toolClass alloc] init];
        [tools addObject:toolInstance];
    }
    
    return tools;
}

- (void)setImage:(UIImage *)image forCropRect:(CGRect)cropRect cropRotation:(CGFloat)cropRotation cropOrientation:(UIImageOrientation)cropOrientation cropMirrored:(bool)cropMirrored fullSize:(bool)fullSize
{
    [_toolComposer invalidate];
    _currentProcessChain = nil;
    
    _imageCropRect = cropRect;
    _imageCropRotation = cropRotation;
    _imageCropOrientation = cropOrientation;
    _imageCropMirrored = cropMirrored;
    
    [_currentInput removeAllTargets];
    _currentInput = [[PhotoEditorPicture alloc] initWithImage:image];
    
    _histogramGenerator.imageSize = image.size;
    
    _fullSize = fullSize;
}

#pragma mark - Properties

- (CGSize)rotatedCropSize
{
    if (_cropOrientation == UIImageOrientationLeft || _cropOrientation == UIImageOrientationRight)
        return CGSizeMake(_cropRect.size.height, _cropRect.size.width);
    
    return _cropRect.size;
}

- (bool)hasDefaultCropping
{
    if (!_CGRectEqualToRectWithEpsilon(self.cropRect, CGRectMake(0, 0, _originalSize.width, _originalSize.height), 1.0f) || self.cropOrientation != UIImageOrientationUp || ABS(self.cropRotation) > FLT_EPSILON || self.cropMirrored)
    {
        return false;
    }
    
    return true;
}

#pragma mark - Processing

- (bool)readyForProcessing
{
    return (_currentInput != nil);
}

- (void)processAnimated:(bool)animated completion:(void (^)(void))completion
{
    [self processAnimated:animated capture:false synchronous:false completion:completion];
}

- (void)processAnimated:(bool)animated capture:(bool)capture synchronous:(bool)synchronous completion:(void (^)(void))completion
{
    if (self.previewOutput == nil)
        return;
    
    if (iosMajorVersion() < 7)
        animated = false;
    
    if (_processing && completion == nil)
    {
        _needsReprocessing = true;
        return;
    }
    
    _processing = true;
    
    [_queue dispatch:^
    {
        NSMutableArray *processChain = [NSMutableArray array];
        
        for (PhotoTool *tool in _toolComposer.advancedTools)
        {
            if (!tool.shouldBeSkipped && tool.pass != nil)
                [processChain addObject:tool.pass];
        }
        
        _toolComposer.imageSize = _cropRect.size;
        [processChain addObject:_toolComposer];
        
        PhotoEditorPreviewView *previewOutput = self.previewOutput;
        
        if (![_currentProcessChain isEqualToArray:processChain])
        {
            [_currentInput removeAllTargets];
            
            for (PhotoProcessPass *pass in _currentProcessChain)
                [pass.filter removeAllTargets];
            
            _currentProcessChain = processChain;
            
            GPUImageOutput <GPUImageInput> *lastFilter = ((PhotoProcessPass *)_currentProcessChain.firstObject).filter;
            [_currentInput addTarget:lastFilter];
            
            NSInteger chainLength = _currentProcessChain.count;
            if (chainLength > 1)
            {
                for (NSInteger i = 1; i < chainLength; i++)
                {
                    PhotoProcessPass *pass = ((PhotoProcessPass *)_currentProcessChain[i]);
                    GPUImageOutput <GPUImageInput> *filter = pass.filter;
                    [lastFilter addTarget:filter];
                    lastFilter = filter;
                }
            }
            _finalFilter = lastFilter;
            
            [_finalFilter addTarget:previewOutput.imageView];
            [_finalFilter addTarget:_histogramGenerator];
        }
                
        if (capture)
            [_finalFilter useNextFrameForImageCapture];
        
        for (PhotoProcessPass *pass in _currentProcessChain)
            [pass process];
        
        if (animated)
        {
            DispatchOnMainThread(^
            {
                [previewOutput prepareTransitionFadeView];
            });
        }
        
        [_currentInput processSynchronous:true completion:^
        {            
            if (completion != nil)
                completion();
            
            _processing = false;
             
            if (animated)
            {
                DispatchOnMainThread(^
                {
                    [previewOutput performTransitionFade];
                });
            }
            
            if (_needsReprocessing && !synchronous)
            {
                _needsReprocessing = false;
                [self processAnimated:false completion:nil];
            }
        }];
    } synchronous:synchronous];
}

#pragma mark - Result

- (void)createResultImageWithCompletion:(void (^)(UIImage *image))completion
{
    [self processAnimated:false capture:true synchronous:false completion:^
    {
        UIImage *image = [_finalFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
        
        if (completion != nil)
            completion(image);
    }];
}

- (UIImage *)currentResultImage
{
    __block UIImage *image = nil;
    [self processAnimated:false capture:true synchronous:true completion:^
    {
        image = [_finalFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
    }];
    return image;
}

#pragma mark - Editor Values

- (void)_importAdjustments:(id<MediaEditAdjustments>)adjustments
{
    _initialAdjustments = adjustments;
    
    if (adjustments != nil)
        self.cropRect = adjustments.cropRect;
    
    self.cropOrientation = adjustments.cropOrientation;
    self.cropLockedAspectRatio = adjustments.cropLockedAspectRatio;
    self.cropMirrored = adjustments.cropMirrored;
    self.paintingData = adjustments.paintingData;
    
    if ([adjustments isKindOfClass:[PhotoEditorValues class]])
    {
        PhotoEditorValues *editorValues = (PhotoEditorValues *)adjustments;

        self.cropRotation = editorValues.cropRotation;

        for (PhotoTool *tool in self.tools)
        {
            id value = editorValues.toolValues[tool.identifier];
            if (value != nil && [value isKindOfClass:[tool valueClass]])
                tool.value = [value copy];
        }
    }
    else if ([adjustments isKindOfClass:[VideoEditAdjustments class]])
    {
        VideoEditAdjustments *videoAdjustments = (VideoEditAdjustments *)adjustments;
        self.trimStartValue = videoAdjustments.trimStartValue;
        self.trimEndValue = videoAdjustments.trimEndValue;
        self.sendAsGif = videoAdjustments.sendAsGif;
        self.preset = videoAdjustments.preset;
    }
}

- (id<MediaEditAdjustments>)exportAdjustments
{
    return [self exportAdjustmentsWithPaintingData:_paintingData];
}

- (id<MediaEditAdjustments>)exportAdjustmentsWithPaintingData:(PaintingData *)paintingData
{
    if (!_forVideo)
    {
        NSMutableDictionary *toolValues = [[NSMutableDictionary alloc] init];
        for (PhotoTool *tool in self.tools)
        {
            if (!tool.shouldBeSkipped)
            {
                if (!([tool.value isKindOfClass:[NSNumber class]] && ABS([tool.value floatValue] - (float)tool.defaultValue) < FLT_EPSILON))
                    toolValues[tool.identifier] = [tool.value copy];
            }
        }
        
        return [PhotoEditorValues editorValuesWithOriginalSize:self.originalSize cropRect:self.cropRect cropRotation:self.cropRotation cropOrientation:self.cropOrientation cropLockedAspectRatio:self.cropLockedAspectRatio cropMirrored:self.cropMirrored toolValues:toolValues paintingData:paintingData];
    }
    else
    {
        VideoEditAdjustments *initialAdjustments = (VideoEditAdjustments *)_initialAdjustments;
        
        return [VideoEditAdjustments editAdjustmentsWithOriginalSize:self.originalSize cropRect:self.cropRect cropOrientation:self.cropOrientation cropLockedAspectRatio:self.cropLockedAspectRatio cropMirrored:self.cropMirrored trimStartValue:initialAdjustments.trimStartValue trimEndValue:initialAdjustments.trimEndValue paintingData:paintingData sendAsGif:self.sendAsGif preset:self.preset];
    }
}

- (SSignal *)histogramSignal
{
    return [[SSignal single:_currentHistogram] then:_histogramPipe.signalProducer()];
}

+ (NSArray *)availableTools
{
    static NSArray *tools;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        tools = @[ [EnhanceTool class],
                   [ExposureTool class],
                   [ContrastTool class],
                   [WarmthTool class],
                   [SaturationTool class],
                   [TintTool class],
                   [FadeTool class],
                   [HighlightsTool class],
                   [ShadowsTool class],
                   [VignetteTool class],
                   [GrainTool class],
                   [BlurTool class],
                   [SharpenTool class],
                   [CurvesTool class] ];
    });
    
    return tools;
}

@end
