
#import "PhotoEditorController.h"

#import "AppDelegate.h"
#import <objc/runtime.h>

#import "ASWatcher.h"

#import <Photos/Photos.h>

#import "PhotoEditorAnimation.h"
#import "PhotoEditorInterfaceAssets.h"
#import "ImageUtils.h"
#import "PhotoEditorUtils.h"
#import "PaintUtils.h"

#import "Hacks.h"
#import "UIImage+TG.h"

#import "ProgressWindow.h"

#import "PhotoEditor.h"
#import "EnhanceTool.h"

#import "PhotoEditorValues.h"
#import "VideoEditAdjustments.h"
#import "PaintingData.h"

#import "MediaVideoConverter.h"

#import "PhotoToolbarView.h"
#import "PhotoEditorPreviewView.h"

#import "MenuView.h"

#import "Common.h"

#import "MediaAssetsLibrary.h"
#import "MediaAssetImageSignals.h"

#import "PhotoCaptionController.h"
#import "PhotoCropController.h"
#import "PhotoAvatarCropController.h"
#import "PhotoToolsController.h"
#import "PhotoPaintController.h"
#import "PhotoDummyController.h"
#import "PhotoQualityController.h"
#import "PhotoEditorItemController.h"

#import "MessageImageViewOverlayView.h"

#import "MenuSheetController.h"

#import "AVURLAsset+MediaItem.h"

@interface PhotoEditorController () <ASWatcher, ViewControllerNavigationBarAppearance, UIDocumentInteractionControllerDelegate>
{
    bool _switchingTab;
    PhotoEditorTab _availableTabs;
    PhotoEditorTab _currentTab;
    PhotoEditorTabController *_currentTabController;
    
    UIView *_backgroundView;
    UIView *_containerView;
    UIView *_wrapperView;
    UIView *_transitionWrapperView;
    PhotoToolbarView *_portraitToolbarView;
    PhotoToolbarView *_landscapeToolbarView;
    PhotoEditorPreviewView *_previewView;
    
    PhotoEditor *_photoEditor;
    
    SQueue *_queue;
    PhotoEditorControllerIntent _intent;
    id<MediaEditableItem> _item;
    UIImage *_screenImage;
    UIImage *_thumbnailImage;
    
    id<MediaEditAdjustments> _initialAdjustments;
    NSString *_caption;
    
    bool _viewFillingWholeScreen;
    bool _forceStatusBarVisible;
    
    bool _ignoreDefaultPreviewViewTransitionIn;
    bool _hasOpenedPhotoTools;
    bool _hiddenToolbarView;
    
    MenuContainerView *_menuContainerView;
    UIDocumentInteractionController *_documentController;
    
    bool _progressVisible;
    MessageImageViewOverlayView *_progressView;
}

@property (nonatomic, weak) UIImage *fullSizeImage;

@end

@implementation PhotoEditorController

@synthesize actionHandle = _actionHandle;

- (instancetype)initWithItem:(id<MediaEditableItem>)item intent:(PhotoEditorControllerIntent)intent adjustments:(id<MediaEditAdjustments>)adjustments caption:(NSString *)caption screenImage:(UIImage *)screenImage availableTabs:(PhotoEditorTab)availableTabs selectedTab:(PhotoEditorTab)selectedTab
{
    self = [super init];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.automaticallyManageScrollViewInsets = false;
        self.autoManageStatusBarBackground = false;
        self.isImportant = true;
        
        _availableTabs = availableTabs;

        _item = item;
        _currentTab = selectedTab;
        _intent = intent;
        
        _caption = caption;
        _initialAdjustments = adjustments;
        _screenImage = screenImage;
        
        _queue = [[SQueue alloc] init];
        _photoEditor = [[PhotoEditor alloc] initWithOriginalSize:_item.originalSize adjustments:adjustments forVideo:(intent == PhotoEditorControllerVideoIntent)];
        if ([self presentedForAvatarCreation])
        {
            CGFloat shortSide = MIN(_item.originalSize.width, _item.originalSize.height);
            _photoEditor.cropRect = CGRectMake((_item.originalSize.width - shortSide) / 2, (_item.originalSize.height - shortSide) / 2, shortSide, shortSide);
        }
                
        if ([adjustments isKindOfClass:[VideoEditAdjustments class]])
        {
            VideoEditAdjustments *videoAdjustments = (VideoEditAdjustments *)adjustments;
            _photoEditor.trimStartValue = videoAdjustments.trimStartValue;
            _photoEditor.trimEndValue = videoAdjustments.trimEndValue;
        }
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
}

- (void)loadView
{
    [super loadView];
    
    self.view.frame = (CGRect){ CGPointZero, [self referenceViewSize]};
    self.view.clipsToBounds = true;
    
    if ([self presentedForAvatarCreation] && ![self presentedFromCamera])
        self.view.backgroundColor = [UIColor blackColor];
    
    _wrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_wrapperView];
    
    _backgroundView = [[UIView alloc] initWithFrame:_wrapperView.bounds];
    _backgroundView.alpha = 0.0f;
    _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _backgroundView.backgroundColor = [PhotoEditorInterfaceAssets toolbarBackgroundColor];
    [_wrapperView addSubview:_backgroundView];
    
    _transitionWrapperView = [[UIView alloc] initWithFrame:_wrapperView.bounds];
    [_wrapperView addSubview:_transitionWrapperView];
    
    _containerView = [[UIView alloc] initWithFrame:CGRectZero];
    [_wrapperView addSubview:_containerView];
    
    __weak PhotoEditorController *weakSelf = self;
    
    void(^toolbarCancelPressed)(void) = ^
    {
        __strong PhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf cancelButtonPressed];
    };
    
    void(^toolbarDonePressed)(void) = ^
    {
        __strong PhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf doneButtonPressed];
    };
    
    void(^toolbarDoneLongPressed)(id) = ^(id sender)
    {
        __strong PhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf doneButtonLongPressed:sender];
    };
    
    void(^toolbarTabPressed)(PhotoEditorTab) = ^(PhotoEditorTab tab)
    {
        __strong PhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        switch (tab)
        {
            default:
                [strongSelf presentEditorTab:tab];
                break;
                
            case PhotoEditorPaintTab:
                if ([strongSelf->_currentTabController isKindOfClass:[PhotoPaintController class]])
                    [strongSelf->_currentTabController handleTabAction:tab];
                else
                    [strongSelf presentEditorTab:tab];
                break;
                
            case PhotoEditorStickerTab:
            case PhotoEditorTextTab:
                [strongSelf->_currentTabController handleTabAction:tab];
                break;
                
            case PhotoEditorRotateTab:
                [strongSelf rotateVideoOrReset:false];
                break;
                
            case PhotoEditorGifTab:
                [strongSelf toggleSendAsGif];
                break;
        }
    };
    
    
    NSString *backButtonTitle = TGLocalized(@"Cancel");
    if ([self presentedForAvatarCreation])
    {
        if ([self presentedFromCamera])
            backButtonTitle = TGLocalized(@"Retake");
        else
            backButtonTitle = TGLocalized(@"Back");
    }

    NSString *doneButtonTitle = [self presentedForAvatarCreation] ? TGLocalized(@"Choose") : TGLocalized(@"Done");

    _portraitToolbarView = [[PhotoToolbarView alloc] initWithBackButtonTitle:backButtonTitle doneButtonTitle:doneButtonTitle accentedDone:![self presentedForAvatarCreation] solidBackground:true];
    [_portraitToolbarView setToolbarTabs:_availableTabs animated:false];
    [_portraitToolbarView setActiveTab:_currentTab];
    _portraitToolbarView.cancelPressed = toolbarCancelPressed;
    _portraitToolbarView.donePressed = toolbarDonePressed;
    _portraitToolbarView.doneLongPressed = toolbarDoneLongPressed;
    _portraitToolbarView.tabPressed = toolbarTabPressed;
    [_wrapperView addSubview:_portraitToolbarView];
    
    _landscapeToolbarView = [[PhotoToolbarView alloc] initWithBackButtonTitle:backButtonTitle doneButtonTitle:doneButtonTitle accentedDone:![self presentedForAvatarCreation] solidBackground:true];
    [_landscapeToolbarView setToolbarTabs:_availableTabs animated:false];
    [_landscapeToolbarView setActiveTab:_currentTab];
    _landscapeToolbarView.cancelPressed = toolbarCancelPressed;
    _landscapeToolbarView.donePressed = toolbarDonePressed;
    _landscapeToolbarView.doneLongPressed = toolbarDoneLongPressed;
    _landscapeToolbarView.tabPressed = toolbarTabPressed;
    
    if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)
        [_wrapperView addSubview:_landscapeToolbarView];
    
    if (_intent & PhotoEditorControllerWebIntent)
        [self updateDoneButtonEnabled:false animated:false];
    
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;
    
    CGRect containerFrame = [PhotoEditorTabController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:[_landscapeToolbarView landscapeSize] orientation:orientation panelSize:PhotoEditorPanelSize];
    CGSize fittedSize = ScaleToSize(_photoEditor.rotatedCropSize, containerFrame.size);
    
    _previewView = [[PhotoEditorPreviewView alloc] initWithFrame:CGRectMake(0, 0, fittedSize.width, fittedSize.height)];
    _previewView.clipsToBounds = true;
    [_previewView setSnapshotImage:_screenImage];
    [_photoEditor setPreviewOutput:_previewView];
    [self updatePreviewView];
    
    NSArray *buttonTitles = nil;
    if ([self presentedForAvatarCreation])
    {
        buttonTitles = @
        [
            backButtonTitle,
            TGLocalized(@"Choose")
        ];
    }
    else
    {
        buttonTitles = @
        [
            backButtonTitle,
            TGLocalized(@"Back"),
            TGLocalized(@"Done"),
            TGLocalized(@"Send")
        ];
    }
    [_landscapeToolbarView calculateLandscapeSizeForPossibleButtonTitles:buttonTitles];
    
    [self updateEditorButtonsWithAdjustments:_initialAdjustments];
    [self presentEditorTab:_currentTab];
}

- (void)setToolbarHidden:(bool)hidden animated:(bool)animated
{
    if (self.requestToolbarsHidden == nil)
        return;
    
    if (_hiddenToolbarView == hidden)
        return;
    
    if (hidden)
    {
        [_portraitToolbarView transitionOutAnimated:animated transparent:true hideOnCompletion:false];
        [_landscapeToolbarView transitionOutAnimated:animated transparent:true hideOnCompletion:false];
    }
    else
    {
        [_portraitToolbarView transitionInAnimated:animated transparent:true];
        [_landscapeToolbarView transitionInAnimated:animated transparent:true];
    }
    
    self.requestToolbarsHidden(hidden, animated);
    _hiddenToolbarView = hidden;
}

- (BOOL)prefersStatusBarHidden
{
    if (_forceStatusBarVisible)
        return false;
    
    if ([self inFormSheet])
        return false;
    
    if (self.navigationController != nil)
        return _viewFillingWholeScreen;
    
    if (self.dontHideStatusBar)
        return false;
    
    return true;
}

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (bool)navigationBarShouldBeHidden
{
    return true;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([_currentTabController isKindOfClass:[PhotoCropController class]] || [_currentTabController isKindOfClass:[PhotoCaptionController class]] || [_currentTabController isKindOfClass:[PhotoAvatarCropController class]])
        return;
    
    NSTimeInterval position = 0;
    MediaVideoEditAdjustments *adjustments = [_photoEditor exportAdjustments];
    if ([adjustments isKindOfClass:[MediaVideoEditAdjustments class]])
        position = adjustments.trimStartValue;
    
    CGSize screenSize = TGNativeScreenSize();
    SSignal *signal = nil;
    if ([_photoEditor hasDefaultCropping] && (NSInteger)screenSize.width == 320)
    {
        signal = [self.requestOriginalScreenSizeImage(_item, position) filter:^bool(id image)
        {
            return [image isKindOfClass:[UIImage class]];
        }];
    }
    else
    {
        signal = [[[self.requestOriginalFullSizeImage(_item, position) deliverOn:_queue] filter:^bool(id image)
        {
            return [image isKindOfClass:[UIImage class]];
        }] map:^UIImage *(UIImage *image)
        {
            return PhotoEditorCrop(image, nil, _photoEditor.cropOrientation, _photoEditor.cropRotation, _photoEditor.cropRect, _photoEditor.cropMirrored, PhotoEditorScreenImageMaxSize(), _photoEditor.originalSize, true);
        }];
    }
    
    [signal startWithNext:^(UIImage *next)
    {
        [_photoEditor setImage:next forCropRect:_photoEditor.cropRect cropRotation:_photoEditor.cropRotation cropOrientation:_photoEditor.cropOrientation cropMirrored:_photoEditor.cropMirrored fullSize:false];
        
        if (_ignoreDefaultPreviewViewTransitionIn)
        {
            DispatchOnMainThread(^
            {
                if ([_currentTabController isKindOfClass:[PhotoDummyController class]])
                    [_previewView setSnapshotImageOnTransition:next];
                else
                    [_previewView setSnapshotImage:next];
            });
        }
        else
        {
            [_photoEditor processAnimated:false completion:^
            {
                DispatchOnMainThread(^
                {
                    [_previewView performTransitionInWithCompletion:^
                    {
                        [_previewView setSnapshotImage:next];
                    }];
                });
            }];
        }
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
    if (![self inFormSheet] && (self.navigationController != nil || self.dontHideStatusBar))
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                [Hacks setApplicationStatusBarAlpha:0.0f];
            }];
        }
        else
        {
            [Hacks setApplicationStatusBarAlpha:0.0f];
        }
    }
    
    [super viewWillAppear:animated];

    [self transitionIn];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (self.navigationController != nil)
    {
        _viewFillingWholeScreen = true;

        if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)])
            [self setNeedsStatusBarAppearanceUpdate];
    }
    
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
    if (self.navigationController != nil || self.dontHideStatusBar)
    {
        _viewFillingWholeScreen = false;
        
        if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)])
            [self setNeedsStatusBarAppearanceUpdate];
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                [Hacks setApplicationStatusBarAlpha:1.0f];
            }];
        }
        else
        {
            [Hacks setApplicationStatusBarAlpha:1.0f];
        }
    }
    
    [super viewWillDisappear:animated];
}

- (void)updateDoneButtonEnabled:(bool)enabled animated:(bool)animated
{
    [_portraitToolbarView setEditButtonsEnabled:enabled animated:animated];
    [_landscapeToolbarView setEditButtonsEnabled:enabled animated:animated];
    
    [_portraitToolbarView setDoneButtonEnabled:enabled animated:animated];
    [_landscapeToolbarView setDoneButtonEnabled:enabled animated:animated];
}

- (void)updateStatusBarAppearanceForDismiss
{
    _forceStatusBarVisible = true;
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)])
        [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)shouldAutorotate
{
    return (!(_currentTabController != nil && ![_currentTabController shouldAutorotate]) && [super shouldAutorotate]);
}

#pragma mark - 

- (void)createEditedImageWithEditorValues:(PhotoEditorValues *)editorValues createThumbnail:(bool)createThumbnail saveOnly:(bool)saveOnly completion:(void (^)(UIImage *))completion
{
    if (!saveOnly)
    {
        bool forAvatar = [self presentedForAvatarCreation];
        if (!forAvatar && [editorValues isDefaultValuesForAvatar:false])
        {
            if (self.willFinishEditing != nil)
                self.willFinishEditing(nil, [_currentTabController currentResultRepresentation], true);
            
            if (self.didFinishEditing != nil)
                self.didFinishEditing(nil, nil, nil, true);

            if (completion != nil)
                completion(nil);
            
            return;
        }
    }
    
    if (!saveOnly && self.willFinishEditing != nil)
        self.willFinishEditing(editorValues, [_currentTabController currentResultRepresentation], true);
    
    if (!saveOnly && completion != nil)
        completion(nil);
    
    UIImage *fullSizeImage = self.fullSizeImage;
    PhotoEditor *photoEditor = _photoEditor;
    
    SSignal *imageSignal = nil;
    if (fullSizeImage == nil)
    {
        imageSignal = [self.requestOriginalFullSizeImage(_item, 0) filter:^bool(id result)
        {
            return [result isKindOfClass:[UIImage class]];
        }];
    }
    else
    {
        imageSignal = [SSignal single:fullSizeImage];
    }
    
    bool hasImageAdjustments = editorValues.toolsApplied || saveOnly;
    bool hasPainting = editorValues.hasPainting;
    
    SSignal *(^imageCropSignal)(UIImage *, bool) = ^(UIImage *image, bool resize)
    {
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            UIImage *paintingImage = !hasImageAdjustments ? editorValues.paintingData.image : nil;
            UIImage *croppedImage = PhotoEditorCrop(image, paintingImage, photoEditor.cropOrientation, photoEditor.cropRotation, photoEditor.cropRect, photoEditor.cropMirrored, PhotoEditorResultImageMaxSize, photoEditor.originalSize, resize);
            [subscriber putNext:croppedImage];
            [subscriber putCompletion];
            
            return nil;
        }];
    };
    
    SSignal *(^imageRenderSignal)(UIImage *) = ^(UIImage *image)
    {
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [photoEditor setImage:image forCropRect:photoEditor.cropRect cropRotation:photoEditor.cropRotation cropOrientation:photoEditor.cropOrientation cropMirrored:photoEditor.cropMirrored fullSize:true];
            [photoEditor createResultImageWithCompletion:^(UIImage *result)
            {
                if (hasPainting)
                {
                    result = PaintCombineCroppedImages(result, editorValues.paintingData.image, true, photoEditor.originalSize, photoEditor.cropRect, photoEditor.cropOrientation, photoEditor.cropRotation, photoEditor.cropMirrored);
                    [PaintingData facilitatePaintingData:editorValues.paintingData];
                }
                
                [subscriber putNext:result];
                [subscriber putCompletion];
            }];
            
            return nil;
        }];
    };

    SSignal *renderedImageSignal = [[imageSignal mapToSignal:^SSignal *(UIImage *image)
    {
        return [imageCropSignal(image, !hasImageAdjustments || hasPainting) startOn:_queue];
    }] mapToSignal:^SSignal *(UIImage *image)
    {
        if (hasImageAdjustments)
            return [[[SSignal complete] delay:0.3 onQueue:_queue] then:imageRenderSignal(image)];
        else
            return [SSignal single:image];
    }];
    
    if (saveOnly)
    {
        [[renderedImageSignal deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
        {
            if (completion != nil)
                completion(image);
        }];
    }
    else
    {
        [[[[renderedImageSignal map:^id(UIImage *image)
        {
            if (!hasImageAdjustments)
            {
                if (hasPainting && self.didFinishRenderingFullSizeImage != nil)
                    self.didFinishRenderingFullSizeImage(image);

                return image;
            }
            else
            {
                if (!saveOnly && self.didFinishRenderingFullSizeImage != nil)
                    self.didFinishRenderingFullSizeImage(image);
                
                return PhotoEditorFitImage(image, PhotoEditorResultImageMaxSize);
            }
        }] map:^NSDictionary *(UIImage *image)
        {
            NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
            if (image != nil)
                result[@"image"] = image;
            
            if (createThumbnail)
            {
                CGSize fillSize = PhotoThumbnailSizeForCurrentScreen();
                fillSize.width = CGCeil(fillSize.width);
                fillSize.height = CGCeil(fillSize.height);
                
                CGSize size = ScaleToFillSize(image.size, fillSize);
                
                UIGraphicsBeginImageContextWithOptions(size, true, 0.0f);
                CGContextRef context = UIGraphicsGetCurrentContext();
                CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
                
                [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
                
                UIImage *thumbnailImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                
                if (thumbnailImage != nil)
                    result[@"thumbnail"] = thumbnailImage;
            }
            
            return result;
        }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *result)
        {
            UIImage *image = result[@"image"];
            UIImage *thumbnailImage = result[@"thumbnail"];
            
            if (!saveOnly && self.didFinishEditing != nil)
                self.didFinishEditing(editorValues, image, thumbnailImage, true);
        } error:^(__unused id error)
        {
            TGLog(@"renderedImageSignal error");
        } completed:nil];
    }
}

#pragma mark - Intent

- (bool)presentedFromCamera
{
    return _intent & PhotoEditorControllerFromCameraIntent;
}

- (bool)presentedForAvatarCreation
{
    return _intent & PhotoEditorControllerAvatarIntent;
}

#pragma mark - Transition

- (void)transitionIn
{
    if (self.navigationController != nil)
        return;
    
    CGFloat delay = [self presentedFromCamera] ? 0.1f: 0.0f;
    
    _portraitToolbarView.alpha = 0.0f;
    _landscapeToolbarView.alpha = 0.0f;
    
    [UIView animateWithDuration:0.3f delay:delay options:UIViewAnimationOptionCurveLinear animations:^
    {
        _portraitToolbarView.alpha = 1.0f;
        _landscapeToolbarView.alpha = 1.0f;
    } completion:nil];
}

- (void)transitionOutSaving:(bool)saving completion:(void (^)(void))completion
{
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolbarView.alpha = 0.0f;
        _landscapeToolbarView.alpha = 0.0f;
    }];
    
    _currentTabController.beginTransitionOut = self.beginTransitionOut;
    [self setToolbarHidden:false animated:true];
    
    if (self.beginCustomTransitionOut != nil)
    {
        id rep = [_currentTabController currentResultRepresentation];
        if ([rep isKindOfClass:[UIImage class]])
        {
            UIImageView *imageView = [[UIImageView alloc] initWithImage:(UIImage *)rep];
            rep = imageView;
        }
        [_currentTabController prepareForCustomTransitionOut];
        self.beginCustomTransitionOut([_currentTabController transitionOutReferenceFrame], rep, completion);
    }
    else
    {
        [_currentTabController transitionOutSaving:saving completion:^
        {
            if (completion != nil)
                completion();
            
            if (self.finishedTransitionOut != nil)
                self.finishedTransitionOut(saving);
        }];
    }
}

- (void)presentEditorTab:(PhotoEditorTab)tab
{    
    if (_switchingTab || (tab == _currentTab && _currentTabController != nil))
        return;
    
    bool isInitialAppearance = true;

    CGRect transitionReferenceFrame = CGRectZero;
    UIView *transitionReferenceView = nil;
    UIView *transitionParentView = nil;
    bool transitionNoTransitionView = false;
    
    UIImage *snapshotImage = nil;
    UIView *snapshotView = nil;
    
    PhotoEditorTabController *currentController = _currentTabController;
    if (currentController != nil)
    {
        if (![currentController isDismissAllowed])
            return;
        
        transitionReferenceFrame = [currentController transitionOutReferenceFrame];
        transitionReferenceView = [currentController transitionOutReferenceView];
        transitionNoTransitionView = [currentController isKindOfClass:[PhotoAvatarCropController class]];
        
        currentController.switchingToTab = tab;
        [currentController transitionOutSwitching:true completion:^
        {
            [currentController removeFromParentViewController];
            [currentController.view removeFromSuperview];
        }];
        
        if ([currentController isKindOfClass:[PhotoCropController class]])
        {
            _backgroundView.alpha = 1.0f;
            [UIView animateWithDuration:0.3f animations:^
            {
                _backgroundView.alpha = 0.0f;
            } completion:nil];
        }
        
        isInitialAppearance = false;
        
        snapshotView = [currentController snapshotView];
    }
    else
    {
        if (self.beginTransitionIn != nil)
            transitionReferenceView = self.beginTransitionIn(&transitionReferenceFrame, &transitionParentView);
        
        if ([self presentedFromCamera] && [self presentedForAvatarCreation])
        {
            if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                transitionReferenceFrame = CGRectMake(self.view.frame.size.width - transitionReferenceFrame.size.height - transitionReferenceFrame.origin.y,
                                                      transitionReferenceFrame.origin.x,
                                                      transitionReferenceFrame.size.height, transitionReferenceFrame.size.width);
            }
            else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
            {
                transitionReferenceFrame = CGRectMake(transitionReferenceFrame.origin.y,
                                                      self.view.frame.size.height - transitionReferenceFrame.size.width - transitionReferenceFrame.origin.x,
                                                      transitionReferenceFrame.size.height, transitionReferenceFrame.size.width);
            }
        }
        
        snapshotImage = _screenImage;
    }
    
    PhotoEditorValues *editorValues = [_photoEditor exportAdjustments];
    [self updateEditorButtonsWithAdjustments:editorValues];
    
    _switchingTab = true;
    
    __weak PhotoEditorController *weakSelf = self;
    PhotoEditorTabController *controller = nil;
    switch (tab)
    {
        case PhotoEditorPaintTab:
        {
            PhotoPaintController *paintController = [[PhotoPaintController alloc] initWithPhotoEditor:_photoEditor previewView:_previewView];
            paintController.toolbarLandscapeSize = _landscapeToolbarView.landscapeSize;
            
            paintController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
            {
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return nil;
                
                *referenceFrame = transitionReferenceFrame;
                *parentView = transitionParentView;
                *noTransitionView = transitionNoTransitionView;
                
                return transitionReferenceView;
            };
            paintController.finishedTransitionIn = ^
            {
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (isInitialAppearance && strongSelf.finishedTransitionIn != nil)
                    strongSelf.finishedTransitionIn();
                
                strongSelf->_switchingTab = false;
            };
            
            controller = paintController;
        }
            break;
            
        case PhotoEditorCaptionTab:
        {
            PhotoCaptionController *captionController = [[PhotoCaptionController alloc] initWithPhotoEditor:_photoEditor
                                                                                                    previewView:_previewView
                                                                                                        caption:_caption];
            captionController.toolbarLandscapeSize = _landscapeToolbarView.landscapeSize;
            captionController.suggestionContext = self.suggestionContext;
            captionController.captionSet = ^(NSString *caption)
            {
                if (caption.length == 0)
                    caption = nil;
                
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf->_caption = caption;
                if (strongSelf.captionSet != nil)
                    strongSelf.captionSet(caption);
                
                [strongSelf doneButtonPressed];
            };
            
            captionController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
            {
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return nil;
                
                *referenceFrame = transitionReferenceFrame;
                *parentView = transitionParentView;
                *noTransitionView = transitionNoTransitionView;

                [strongSelf->_portraitToolbarView transitionOutAnimated:!isInitialAppearance transparent:true hideOnCompletion:true];
                [strongSelf->_landscapeToolbarView transitionOutAnimated:!isInitialAppearance transparent:true hideOnCompletion:true];
                
                return transitionReferenceView;
            };
            captionController.finishedTransitionIn = ^
            {
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (isInitialAppearance && strongSelf.finishedTransitionIn != nil)
                    strongSelf.finishedTransitionIn();
                
                strongSelf->_switchingTab = false;
            };
            
            controller = captionController;
            
            [self setToolbarHidden:true animated:isInitialAppearance];
        }
            break;
            
        case PhotoEditorCropTab:
        {
            __block UIView *initialBackgroundView = nil;
            
            if ([self presentedForAvatarCreation])
            {
                PhotoAvatarCropController *cropController = [[PhotoAvatarCropController alloc] initWithPhotoEditor:_photoEditor previewView:_previewView];
                
                bool skipInitialTransition = (![self presentedFromCamera] && self.navigationController != nil) || self.skipInitialTransition;
                cropController.fromCamera = [self presentedFromCamera];
                cropController.skipTransitionIn = skipInitialTransition;
                if (snapshotView != nil)
                    [cropController setSnapshotView:snapshotView];
                else if (snapshotImage != nil)
                    [cropController setSnapshotImage:snapshotImage];
                cropController.toolbarLandscapeSize = _landscapeToolbarView.landscapeSize;
                cropController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
                {
                    __strong PhotoEditorController *strongSelf = weakSelf;
                    *referenceFrame = transitionReferenceFrame;
                    *noTransitionView = transitionNoTransitionView;
                    *parentView = transitionParentView;
                    
                    if (strongSelf != nil)
                    {
                        UIView *backgroundView = nil;
                        if (!skipInitialTransition)
                        {
                            UIView *backgroundSuperview = transitionParentView;
                            if (backgroundSuperview == nil)
                                backgroundSuperview = transitionReferenceView.superview.superview;
                            
                            initialBackgroundView = [[UIView alloc] initWithFrame:backgroundSuperview.bounds];
                            initialBackgroundView.alpha = 0.0f;
                            initialBackgroundView.backgroundColor = [PhotoEditorInterfaceAssets toolbarBackgroundColor];
                            [backgroundSuperview addSubview:initialBackgroundView];
                            backgroundView = initialBackgroundView;
                        }
                        else
                        {
                            backgroundView = strongSelf->_backgroundView;
                        }
                        
                        [UIView animateWithDuration:0.3f animations:^
                        {
                            backgroundView.alpha = 1.0f;
                        }];
                    }
                    
                    return transitionReferenceView;
                };
                cropController.finishedTransitionIn = ^
                {
                    __strong PhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if (!skipInitialTransition)
                    {
                        [initialBackgroundView removeFromSuperview];
                        if (strongSelf.finishedTransitionIn != nil)
                            strongSelf.finishedTransitionIn();
                    }
                    else
                    {
                        strongSelf->_backgroundView.alpha = 0.0f;
                    }
                    
                    strongSelf->_switchingTab = false;
                };
                cropController.finishedTransitionOut = ^
                {
                    __strong PhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if (strongSelf->_currentTabController.finishedTransitionIn != nil)
                    {
                        strongSelf->_currentTabController.finishedTransitionIn();
                        strongSelf->_currentTabController.finishedTransitionIn = nil;
                    }
                    
                    [strongSelf->_currentTabController _finishedTransitionInWithView:nil];
                };
                
                [[[[self.requestOriginalFullSizeImage(_item, 0) reduceLeftWithPassthrough:nil with:^id(__unused id current, __unused id next, void (^emit)(id))
                {
                    if ([next isKindOfClass:[UIImage class]])
                    {
                        if ([next degraded])
                        {
                            emit(next);
                            return current;
                        }
                        return next;
                    }
                    else
                    {
                        return current;
                    }
                }] filter:^bool(id result)
                {
                    return (result != nil);
                }] deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
                {
                    if (cropController.dismissing && !cropController.switching)
                        return;
                    
                    [self updateDoneButtonEnabled:!image.degraded animated:true];
                    if (image.degraded)
                    {
                        return;
                    }
                    else
                    {
                        self.fullSizeImage = image;
                        [cropController setImage:image];
                    }
                }];
                
                controller = cropController;
            }
            else
            {
                PhotoCropController *cropController = [[PhotoCropController alloc] initWithPhotoEditor:_photoEditor
                                                                                               previewView:_previewView
                                                                                                  metadata:self.metadata
                                                                                                  forVideo:(_intent == PhotoEditorControllerVideoIntent)];
                if (snapshotView != nil)
                    [cropController setSnapshotView:snapshotView];
                else if (snapshotImage != nil)
                    [cropController setSnapshotImage:snapshotImage];
                cropController.toolbarLandscapeSize = _landscapeToolbarView.landscapeSize;
                cropController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
                {
                    *referenceFrame = transitionReferenceFrame;
                    *noTransitionView = transitionNoTransitionView;
                    *parentView = transitionParentView;
                    
                    __strong PhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf != nil)
                    {
                        UIView *backgroundView = nil;
                        if (isInitialAppearance)
                        {
                            UIView *backgroundSuperview = transitionParentView;
                            if (backgroundSuperview == nil)
                                backgroundSuperview = transitionReferenceView.superview.superview;
                            
                            initialBackgroundView = [[UIView alloc] initWithFrame:backgroundSuperview.bounds];
                            initialBackgroundView.alpha = 0.0f;
                            initialBackgroundView.backgroundColor = [PhotoEditorInterfaceAssets toolbarBackgroundColor];
                            [backgroundSuperview addSubview:initialBackgroundView];
                            backgroundView = initialBackgroundView;
                        }
                        else
                        {
                            backgroundView = strongSelf->_backgroundView;
                        }
                        
                        [UIView animateWithDuration:0.3f animations:^
                        {
                            backgroundView.alpha = 1.0f;
                        }];
                    }
                    
                    return transitionReferenceView;
                };
                cropController.finishedTransitionIn = ^
                {
                    __strong PhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if (isInitialAppearance)
                    {
                        [initialBackgroundView removeFromSuperview];
                        if (strongSelf.finishedTransitionIn != nil)
                            strongSelf.finishedTransitionIn();
                    }
                    else
                    {
                        strongSelf->_backgroundView.alpha = 0.0f;
                    }
                    
                    strongSelf->_switchingTab = false;
                };
                cropController.cropReset = ^
                {
                    __strong PhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    [strongSelf rotateVideoOrReset:true];
                };
                
                if (_intent != PhotoEditorControllerVideoIntent)
                {
                    [[self.requestOriginalFullSizeImage(_item, 0) deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
                    {
                        if (cropController.dismissing && !cropController.switching)
                            return;
                        
                        if (![image isKindOfClass:[UIImage class]] || image.degraded)
                            return;
                        
                        self.fullSizeImage = image;
                        [cropController setImage:image];
                    }];
                }
                else if (self.requestImage != nil)
                {
                    UIImage *image = self.requestImage();
                    [cropController setImage:image];
                }
                
                controller = cropController;
            }
        }
            break;
            
        case PhotoEditorToolsTab:
        {
            PhotoToolsController *toolsController = [[PhotoToolsController alloc] initWithPhotoEditor:_photoEditor
                                                                                              previewView:_previewView];
            toolsController.toolbarLandscapeSize = _landscapeToolbarView.landscapeSize;

            PhotoEditorItemController *enhanceController = nil;
            if (![editorValues toolsApplied] && !_hasOpenedPhotoTools)
            {
                _ignoreDefaultPreviewViewTransitionIn = true;
                _hasOpenedPhotoTools = true;
                
                EnhanceTool *enhanceTool = nil;
                for (PhotoTool *tool in _photoEditor.tools)
                {
                    if ([tool isKindOfClass:[EnhanceTool class]])
                    {
                        enhanceTool = (EnhanceTool *)tool;
                        break;
                    }
                }
            
                enhanceController = [[PhotoEditorItemController alloc] initWithEditorItem:enhanceTool
                                                                                photoEditor:_photoEditor
                                                                                previewView:nil];
                enhanceController.toolbarLandscapeSize = _landscapeToolbarView.landscapeSize;
                enhanceController.initialAppearance = true;
                
                if ([_currentTabController isKindOfClass:[PhotoCropController class]] || [_currentTabController isKindOfClass:[PhotoAvatarCropController class]])
                {
                    enhanceController.skipProcessingOnCompletion = true;
                    
                    void (^block)(void) = ^
                    {
                        enhanceController.skipProcessingOnCompletion = false;
                    };
                    
                    if ([_currentTabController isKindOfClass:[PhotoCropController class]])
                        ((PhotoCropController *)_currentTabController).finishedPhotoProcessing = block;
                    else if ([_currentTabController isKindOfClass:[PhotoAvatarCropController class]])
                        ((PhotoAvatarCropController *)_currentTabController).finishedPhotoProcessing = block;
                }
                
                __weak PhotoToolsController *weakToolsController = toolsController;
                enhanceController.editorItemUpdated = ^
                {
                    __strong PhotoToolsController *strongToolsController = weakToolsController;
                    if (strongToolsController != nil)
                        [strongToolsController updateValues];
                };
                
                enhanceController.beginTransitionOut = ^
                {
                    __strong PhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if (strongSelf->_currentTabController.beginItemTransitionOut != nil)
                        strongSelf->_currentTabController.beginItemTransitionOut();
                };
                
                enhanceController.finishedCombinedTransition = ^
                {
                    __strong PhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    strongSelf->_ignoreDefaultPreviewViewTransitionIn = false;
                };
                
                [self addChildViewController:enhanceController];
            }
            
            __weak PhotoEditorItemController *weakEnhanceController = enhanceController;
            
            toolsController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
            {
                *referenceFrame = transitionReferenceFrame;
                *parentView = transitionParentView;
                *noTransitionView = transitionNoTransitionView;
                
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    __strong PhotoEditorItemController *strongEnhanceController = weakEnhanceController;
                    if (strongEnhanceController != nil)
                    {
                        if (isInitialAppearance)
                        {
                            strongSelf->_portraitToolbarView.hidden = true;
                            strongSelf->_landscapeToolbarView.hidden = true;
                        }
                        [(PhotoToolsController *)strongSelf->_currentTabController prepareForCombinedAppearance];
                        [strongSelf.view addSubview:strongEnhanceController.view];
                        
                        [strongEnhanceController prepareForCombinedAppearance];
                        
                        CGSize referenceSize = [strongSelf referenceViewSize];
                        strongEnhanceController.view.frame = CGRectMake(0, 0, referenceSize.width, referenceSize.height);
                        
                        strongEnhanceController.view.clipsToBounds = true;
                    }
                }
                
                return transitionReferenceView;
            };
            toolsController.finishedTransitionIn = ^
            {
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (isInitialAppearance && strongSelf.finishedTransitionIn != nil)
                    strongSelf.finishedTransitionIn();
                
                __strong PhotoEditorItemController *strongEnhanceController = weakEnhanceController;
                if (strongEnhanceController != nil)
                {
                    [strongEnhanceController attachPreviewView:strongSelf->_previewView];
                    
                    strongSelf->_portraitToolbarView.hidden = false;
                    strongSelf->_landscapeToolbarView.hidden = false;
                    [(PhotoToolsController *)strongSelf->_currentTabController finishedCombinedAppearance];
                    [strongEnhanceController finishedCombinedAppearance];
                }
                
                strongSelf->_switchingTab = false;
            };
            
            controller = toolsController;
        }
            break;
            
        case PhotoEditorQualityTab:
        {
            PhotoDummyController *dummyController = [[PhotoDummyController alloc] initWithPhotoEditor:_photoEditor
                                                                                              previewView:_previewView];
            dummyController.toolbarLandscapeSize = _landscapeToolbarView.landscapeSize;
            
            PhotoQualityController *qualityController = [[PhotoQualityController alloc] initWithPhotoEditor:_photoEditor];
            qualityController.item = _item;
            dummyController.controller = qualityController;
            
            qualityController.toolbarLandscapeSize = _landscapeToolbarView.landscapeSize;
            qualityController.mainController = self;
            
            _ignoreDefaultPreviewViewTransitionIn = true;
            
            qualityController.beginTransitionOut = ^
            {
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (strongSelf->_currentTabController.beginItemTransitionOut != nil)
                    strongSelf->_currentTabController.beginItemTransitionOut();
            };
            
            qualityController.finishedCombinedTransition = ^
            {
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf->_ignoreDefaultPreviewViewTransitionIn = false;
            };
            
            [self addChildViewController:qualityController];
            
            __weak PhotoQualityController *weakQualityController = qualityController;
            
            dummyController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
            {
                *referenceFrame = transitionReferenceFrame;
                *parentView = transitionParentView;
                *noTransitionView = transitionNoTransitionView;
                
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    __strong PhotoQualityController *strongQualityController = weakQualityController;
                    if (strongQualityController != nil)
                    {
                        if (isInitialAppearance)
                        {
                            strongSelf->_portraitToolbarView.hidden = true;
                            strongSelf->_landscapeToolbarView.hidden = true;
                        }
                        [(PhotoToolsController *)strongSelf->_currentTabController prepareForCombinedAppearance];
                        [strongSelf.view addSubview:strongQualityController.view];
                        
                        [strongQualityController prepareForCombinedAppearance];
                        
                        CGSize referenceSize = [strongSelf referenceViewSize];
                        strongQualityController.view.frame = CGRectMake(0, 0, referenceSize.width, referenceSize.height);
                        
                        strongQualityController.view.clipsToBounds = true;
                    }
                }
                
                return transitionReferenceView;
            };
            dummyController.finishedTransitionIn = ^
            {
                __strong PhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (isInitialAppearance && strongSelf.finishedTransitionIn != nil)
                    strongSelf.finishedTransitionIn();
                
                __strong PhotoQualityController *strongQualityController = weakQualityController;
                if (strongQualityController != nil)
                {
                    [strongQualityController attachPreviewView:strongSelf->_previewView];
                    
                    strongSelf->_portraitToolbarView.hidden = false;
                    strongSelf->_landscapeToolbarView.hidden = false;
                    [(PhotoToolsController *)strongSelf->_currentTabController finishedCombinedAppearance];
                    [strongQualityController finishedCombinedAppearance];
                }
                
                strongSelf->_switchingTab = false;
            };
            
            controller = dummyController;
        }
            break;
            
        default:
        {

        }
            break;
    }
    
    _currentTabController = controller;
    _currentTabController.item = _item;
    _currentTabController.intent = _intent;
    _currentTabController.initialAppearance = isInitialAppearance;
    
    if (![_currentTabController isKindOfClass:[PhotoPaintController class]])
        _currentTabController.availableTabs = _availableTabs;
    
    if ([self presentedForAvatarCreation] && self.navigationController == nil)
        _currentTabController.transitionSpeed = 20.0f;
    
    [self addChildViewController:_currentTabController];
    [_containerView addSubview:_currentTabController.view];

    _currentTabController.view.frame = _containerView.bounds;
    
    _currentTabController.beginItemTransitionIn = ^
    {
        __strong PhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        UIInterfaceOrientation orientation = strongSelf.interfaceOrientation;
        if ([strongSelf inFormSheet])
            orientation = UIInterfaceOrientationPortrait;
        
        if (UIInterfaceOrientationIsPortrait(orientation))
        {
            [strongSelf->_portraitToolbarView transitionOutAnimated:true];
            [strongSelf->_landscapeToolbarView transitionOutAnimated:false];
        }
        else
        {
            [strongSelf->_portraitToolbarView transitionOutAnimated:false];
            [strongSelf->_landscapeToolbarView transitionOutAnimated:true];
        }
    };
    _currentTabController.beginItemTransitionOut = ^
    {
        __strong PhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        UIInterfaceOrientation orientation = strongSelf.interfaceOrientation;
        if ([strongSelf inFormSheet])
            orientation = UIInterfaceOrientationPortrait;
        
        if (UIInterfaceOrientationIsPortrait(orientation))
        {
            [strongSelf->_portraitToolbarView transitionInAnimated:true];
            [strongSelf->_landscapeToolbarView transitionInAnimated:false];
        }
        else
        {
            [strongSelf->_portraitToolbarView transitionInAnimated:false];
            [strongSelf->_landscapeToolbarView transitionInAnimated:true];
        }
    };
    _currentTabController.valuesChanged = ^
    {
        __strong PhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf updatePreviewView];
    };
    
    _currentTab = tab;
    
    [_portraitToolbarView setToolbarTabs:[_currentTabController availableTabs] animated:true];
    [_landscapeToolbarView setToolbarTabs:[_currentTabController availableTabs] animated:true];
    
    [_portraitToolbarView setActiveTab:tab];
    [_landscapeToolbarView setActiveTab:tab];
}

- (void)updatePreviewView
{
    [_previewView setPaintingImageWithData:_photoEditor.paintingData];
    [_previewView setCropRect:_photoEditor.cropRect cropOrientation:_photoEditor.cropOrientation cropRotation:_photoEditor.cropRotation cropMirrored:_photoEditor.cropMirrored originalSize:_photoEditor.originalSize];
}

- (void)updateEditorButtonsWithAdjustments:(id<MediaEditAdjustments>)adjustments
{
    PhotoEditorTab highlightedButtons = [PhotoEditorTabController highlightedButtonsForEditorValues:adjustments forAvatar:[self presentedForAvatarCreation]];
    [_portraitToolbarView setEditButtonsHighlighted:highlightedButtons];
    [_landscapeToolbarView setEditButtonsHighlighted:highlightedButtons];
    
    
    PhotoEditorButton *qualityButton = [_portraitToolbarView buttonForTab:PhotoEditorQualityTab];
    if (qualityButton != nil)
    {
        MediaVideoConversionPreset preset = 0;
        MediaVideoConversionPreset adjustmentsPreset = MediaVideoConversionPresetCompressedDefault;
        if ([adjustments isKindOfClass:[MediaVideoEditAdjustments class]])
            adjustmentsPreset = ((MediaVideoEditAdjustments *)adjustments).preset;
        
        if (adjustmentsPreset != MediaVideoConversionPresetCompressedDefault)
        {
            preset = adjustmentsPreset;
        }
        else
        {
            NSNumber *presetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"TG_preferredVideoPreset_v0"];
            if (presetValue != nil)
                preset = (MediaVideoConversionPreset)[presetValue integerValue];
            else
                preset = MediaVideoConversionPresetCompressedMedium;
        }
        
        MediaVideoConversionPreset bestPreset = [MediaVideoConverter bestAvailablePresetForDimensions:_item.originalSize];
        if (preset > bestPreset)
            preset = bestPreset;
        
        UIImage *icon = [PhotoEditorInterfaceAssets qualityIconForPreset:preset];
        qualityButton.iconImage = icon;
        
        qualityButton = [_landscapeToolbarView buttonForTab:PhotoEditorQualityTab];
        qualityButton.iconImage = icon;
    }
}

- (void)rotateVideoOrReset:(bool)reset
{
    if (_intent != PhotoEditorControllerVideoIntent)
        return;
    
    PhotoCropController *cropController = (PhotoCropController *)_currentTabController;
    if (![cropController isKindOfClass:[PhotoCropController class]])
        return;
    
    if (!reset)
        [cropController rotate];
    
    VideoEditAdjustments *adjustments = (VideoEditAdjustments *)self.requestAdjustments(_item);
    
    PhotoEditor *editor = _photoEditor;
    CGRect cropRect = (adjustments != nil) ? adjustments.cropRect : CGRectMake(0, 0, editor.originalSize.width, editor.originalSize.height);
    VideoEditAdjustments *updatedAdjustments = [VideoEditAdjustments editAdjustmentsWithOriginalSize:editor.originalSize cropRect:cropRect cropOrientation:reset ? UIImageOrientationUp : cropController.cropOrientation cropLockedAspectRatio:adjustments.cropLockedAspectRatio cropMirrored:adjustments.cropMirrored trimStartValue:adjustments.trimStartValue trimEndValue:adjustments.trimEndValue paintingData:adjustments.paintingData sendAsGif:adjustments.sendAsGif preset:adjustments.preset];
    
    [self updateEditorButtonsWithAdjustments:updatedAdjustments];
}

- (void)toggleSendAsGif
{
    if (_intent != PhotoEditorControllerVideoIntent)
        return;
    
    PhotoEditor *editor = _photoEditor;
    

    NSTimeInterval trimStartValue = editor.trimStartValue;
    NSTimeInterval trimEndValue = editor.trimEndValue;
    
    if (trimEndValue < DBL_EPSILON)
    {
        if ([_item isKindOfClass:[MediaAsset class]])
        {
            MediaAsset *asset = (MediaAsset *)_item;
            trimEndValue = asset.videoDuration;
        }
        else if ([_item isKindOfClass:[AVAsset class]])
        {
            AVAsset *asset = (AVAsset *)_item;
            trimEndValue = CMTimeGetSeconds(asset.duration);
        }
    }
    
    NSTimeInterval trimDuration = trimEndValue - trimStartValue;
    
    bool sendAsGif = !editor.sendAsGif;
    if (sendAsGif)
    {
        if (trimDuration > VideoEditMaximumGifDuration)
            trimEndValue = trimStartValue + VideoEditMaximumGifDuration;
    }
    
    VideoEditAdjustments *updatedAdjustments = [VideoEditAdjustments editAdjustmentsWithOriginalSize:editor.originalSize cropRect:editor.cropRect cropOrientation:editor.cropOrientation cropLockedAspectRatio:editor.cropLockedAspectRatio cropMirrored:editor.cropMirrored trimStartValue:trimStartValue trimEndValue:trimEndValue paintingData:editor.paintingData sendAsGif:sendAsGif preset:editor.preset];
    
    editor.trimStartValue = trimStartValue;
    editor.trimEndValue = trimEndValue;
    editor.sendAsGif = sendAsGif;
    
    [self updateEditorButtonsWithAdjustments:updatedAdjustments];
}

- (void)dismissAnimated:(bool)animated
{
    self.view.userInteractionEnabled = false;
    
    if (animated)
    {
        const CGFloat velocity = 2000.0f;
        CGFloat duration = self.view.frame.size.height / velocity;
        CGRect targetFrame = CGRectOffset(self.view.frame, 0, self.view.frame.size.height);
        
        [UIView animateWithDuration:duration animations:^
        {
            self.view.frame = targetFrame;
        } completion:^(__unused BOOL finished)
        {
            [self dismiss];
        }];
    }
    else
    {
        [self dismiss];
    }
}

- (void)cancelButtonPressed
{
    [self dismissEditor];
}

- (void)dismissEditor
{
    if (![_currentTabController isDismissAllowed])
        return;
 
    __weak PhotoEditorController *weakSelf = self;
    void(^dismiss)(void) = ^
    {
        __strong PhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf.view.userInteractionEnabled = false;
        [strongSelf->_currentTabController prepareTransitionOutSaving:false];
        
        if (strongSelf.navigationController != nil)
        {
            [strongSelf.navigationController popViewControllerAnimated:true];
        }
        else
        {
            [strongSelf transitionOutSaving:false completion:^
            {
                [strongSelf dismiss];
            }];
        }
        
        if (strongSelf.willFinishEditing != nil)
            strongSelf.willFinishEditing(nil, nil, false);
        
        if (strongSelf.didFinishEditing != nil)
            strongSelf.didFinishEditing(nil, nil, nil, false);
    };
    
    PaintingData *paintingData = nil;
    if ([_currentTabController isKindOfClass:[PhotoPaintController class]])
        paintingData = [(PhotoPaintController *)_currentTabController paintingData];
    
    PhotoEditorValues *editorValues = paintingData == nil ? [_photoEditor exportAdjustments] : [_photoEditor exportAdjustmentsWithPaintingData:paintingData];
    
    if ((_initialAdjustments == nil && (![editorValues isDefaultValuesForAvatar:[self presentedForAvatarCreation]] || editorValues.cropOrientation != UIImageOrientationUp)) || (_initialAdjustments != nil && ![editorValues isEqual:_initialAdjustments]))
    {
        MenuSheetController *controller = [[MenuSheetController alloc] init];
        controller.dismissesByOutsideTap = true;
        controller.narrowInLandscape = true;
        __weak MenuSheetController *weakController = controller;
        
        NSArray *items = @
        [
            [[MenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"DiscardChanges") type:MenuSheetButtonTypeDefault action:^
            {
                __strong MenuSheetController *strongController = weakController;
                if (strongController == nil)
                    return;
                
                [strongController dismissAnimated:true manual:false completion:^
                {
                    dismiss();
                }];
            }],
            [[MenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Cancel") type:MenuSheetButtonTypeCancel action:^
            {
                __strong MenuSheetController *strongController = weakController;
                if (strongController != nil)
                    [strongController dismissAnimated:true];
            }]
        ];
        
        [controller setItemViews:items];
        controller.sourceRect = ^
        {
            __strong PhotoEditorController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return CGRectZero;
            
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
                return [strongSelf.view convertRect:strongSelf->_portraitToolbarView.cancelButtonFrame fromView:strongSelf->_portraitToolbarView];
            else
                return [strongSelf.view convertRect:strongSelf->_landscapeToolbarView.cancelButtonFrame fromView:strongSelf->_landscapeToolbarView];
        };
        [controller presentInViewController:self sourceView:self.view animated:true];
    }
    else
    {
        dismiss();
    }
}

- (void)doneButtonPressed
{
    [self applyEditor];
}

- (void)applyEditor
{
    if (![_currentTabController isDismissAllowed])
        return;
    
    self.view.userInteractionEnabled = false;
    [_currentTabController prepareTransitionOutSaving:true];
    
    PaintingData *paintingData = _photoEditor.paintingData;
    bool saving = true;
    if ([_currentTabController isKindOfClass:[PhotoPaintController class]])
    {
        PhotoPaintController *paintController = (PhotoPaintController *)_currentTabController;
        paintingData = [paintController paintingData];
        
        _photoEditor.paintingData = paintingData;
        
        if (paintingData != nil)
            [PaintingData storePaintingData:paintingData inContext:_editingContext forItem:_item forVideo:(_intent == PhotoEditorControllerVideoIntent)];
    }
    else if ([_currentTabController isKindOfClass:[PhotoDummyController class]])
    {
        PhotoQualityController *qualityController = ((PhotoDummyController *)_currentTabController).controller;
        _photoEditor.preset = qualityController.preset;
        saving = false;
    }
    
    if (_intent != PhotoEditorControllerVideoIntent)
    {
        ProgressWindow *progressWindow = [[ProgressWindow alloc] init];
        progressWindow.windowLevel = self.view.window.windowLevel + 0.001f;
        [progressWindow performSelector:@selector(showAnimated) withObject:nil afterDelay:0.5];
        
        bool forAvatar = [self presentedForAvatarCreation];
        PhotoEditorValues *editorValues = [_photoEditor exportAdjustmentsWithPaintingData:paintingData];
        [self createEditedImageWithEditorValues:editorValues createThumbnail:!forAvatar saveOnly:false completion:^(__unused UIImage *image)
        {
            [NSObject cancelPreviousPerformRequestsWithTarget:progressWindow selector:@selector(showAnimated) object:nil];
            [progressWindow dismiss:true];
            
            if (forAvatar)
                return;
            
            [self transitionOutSaving:true completion:^
            {
                [self dismiss];
            }];
        }];
    }
    else
    {
        VideoEditAdjustments *adjustments = [_photoEditor exportAdjustmentsWithPaintingData:paintingData];
        bool hasChanges = !(_initialAdjustments == nil && [adjustments isDefaultValuesForAvatar:false] && adjustments.cropOrientation == UIImageOrientationUp);
        
        if (adjustments.paintingData != nil || adjustments.hasPainting != _initialAdjustments.hasPainting)
        {
            [[SQueue concurrentDefaultQueue] dispatch:^
            {
                id<MediaEditableItem> item = _item;
                SSignal *assetSignal = [item isKindOfClass:[MediaAsset class]] ? [MediaAssetImageSignals avAssetForVideoAsset:(MediaAsset *)item] : [SSignal single:((AVAsset *)item)];
                
                [assetSignal startWithNext:^(AVAsset *asset)
                {
                    CGSize videoDimensions = CGSizeZero;
                    if ([item isKindOfClass:[MediaAsset class]])
                        videoDimensions = ((MediaAsset *)item).dimensions;
                    else if ([asset isKindOfClass:[AVURLAsset class]])
                        videoDimensions = ((AVURLAsset *)asset).originalSize;
                    
                    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
                    generator.appliesPreferredTrackTransform = true;
                    generator.maximumSize = TGFitSize(videoDimensions, CGSizeMake(1280.0f, 1280.0f));
                    generator.requestedTimeToleranceAfter = kCMTimeZero;
                    generator.requestedTimeToleranceBefore = kCMTimeZero;
                    
                    CGImageRef imageRef = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(adjustments.trimStartValue, NSEC_PER_SEC) actualTime:nil error:NULL];
                    UIImage *image = [UIImage imageWithCGImage:imageRef];
                    CGImageRelease(imageRef);
                    
                    CGSize thumbnailSize = PhotoThumbnailSizeForCurrentScreen();
                    thumbnailSize.width = CGCeil(thumbnailSize.width);
                    thumbnailSize.height = CGCeil(thumbnailSize.height);
                    
                    CGSize fillSize = ScaleToFillSize(videoDimensions, thumbnailSize);
                    
                    UIImage *thumbnailImage = nil;
                    
                    UIGraphicsBeginImageContextWithOptions(fillSize, true, 0.0f);
                    CGContextRef context = UIGraphicsGetCurrentContext();
                    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
                    
                    [image drawInRect:CGRectMake(0, 0, fillSize.width, fillSize.height)];
                    
                    if (adjustments.paintingData.image != nil)
                        [adjustments.paintingData.image drawInRect:CGRectMake(0, 0, fillSize.width, fillSize.height)];
                    
                    thumbnailImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    
                    [_editingContext setImage:image thumbnailImage:thumbnailImage forItem:_item synchronous:true];
                }];
            }];
        }
        
        if (self.willFinishEditing != nil)
            self.willFinishEditing(hasChanges ? adjustments : nil, nil, hasChanges);
        
        if (self.didFinishEditing != nil)
            self.didFinishEditing(hasChanges ? adjustments : nil, nil, nil, hasChanges);
        
        [self transitionOutSaving:saving completion:^
        {
            [self dismiss];
        }];
    }
}

- (void)doneButtonLongPressed:(UIButton *)sender
{
    if (_menuContainerView != nil)
    {
        [_menuContainerView removeFromSuperview];
        _menuContainerView = nil;
    }

    _menuContainerView = [[MenuContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height)];
    [self.view addSubview:_menuContainerView];
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"instagram://"]])
        [actions addObject:@{ @"title": @"Share on Instagram", @"action": @"instagram" }];
    [actions addObject:@{ @"title": @"Save to Camera Roll", @"action": @"save" }];
    
    [_menuContainerView.menuView setButtonsAndActions:actions watcherHandle:_actionHandle];
    [_menuContainerView.menuView sizeToFit];
    
    CGRect titleLockIconViewFrame = [sender.superview convertRect:sender.frame toView:_menuContainerView];
    titleLockIconViewFrame.origin.y += 16.0f;
    [_menuContainerView showMenuFromRect:titleLockIconViewFrame animated:false];
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"menuAction"])
    {
        NSString *menuAction = options[@"action"];
        if ([menuAction isEqualToString:@"save"])
            [self _saveToCameraRoll];
        else if ([menuAction isEqualToString:@"instagram"])
            [self _openInInstagram];
    }
}

#pragma mark - External Export

- (void)_saveToCameraRoll
{
    ProgressWindow *progressWindow = [[ProgressWindow alloc] init];
    progressWindow.windowLevel = self.view.window.windowLevel + 0.001f;
    [progressWindow performSelector:@selector(showAnimated) withObject:nil afterDelay:0.5];
    
    PaintingData *paintingData = nil;
    if ([_currentTabController isKindOfClass:[PhotoPaintController class]])
        paintingData = [(PhotoPaintController *)_currentTabController paintingData];
    
    PhotoEditorValues *editorValues = paintingData == nil ? [_photoEditor exportAdjustments] : [_photoEditor exportAdjustmentsWithPaintingData:paintingData];
    
    [self createEditedImageWithEditorValues:editorValues createThumbnail:false saveOnly:true completion:^(UIImage *resultImage)
    {
        [[[[MediaAssetsLibrary sharedLibrary] saveAssetWithImage:resultImage] deliverOn:[SQueue mainQueue]] startWithNext:nil completed:^
        {
            [NSObject cancelPreviousPerformRequestsWithTarget:progressWindow selector:@selector(showAnimated) object:nil];
            [progressWindow dismissWithSuccess];
        }];
    }];
}

- (void)_openInInstagram
{
    ProgressWindow *progressWindow = [[ProgressWindow alloc] init];
    progressWindow.windowLevel = self.view.window.windowLevel + 0.001f;
    [progressWindow performSelector:@selector(showAnimated) withObject:nil afterDelay:0.5];
    
    PaintingData *paintingData = nil;
    if ([_currentTabController isKindOfClass:[PhotoPaintController class]])
        paintingData = [(PhotoPaintController *)_currentTabController paintingData];
    
    PhotoEditorValues *editorValues = paintingData == nil ? [_photoEditor exportAdjustments] : [_photoEditor exportAdjustmentsWithPaintingData:paintingData];
    
    [self createEditedImageWithEditorValues:editorValues createThumbnail:false saveOnly:true completion:^(UIImage *resultImage)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:progressWindow selector:@selector(showAnimated) object:nil];
        [progressWindow dismiss:true];
        
        NSData *imageData = UIImageJPEGRepresentation(resultImage, 0.9);
        NSString *writePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"instagram.igo"];
        if (![imageData writeToFile:writePath atomically:true])
        {
            return;
        }
        
        NSURL *fileURL = [NSURL fileURLWithPath:writePath];
        
        _documentController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
        _documentController.delegate = self;
        [_documentController setUTI:@"com.instagram.exclusivegram"];
        if (_caption.length > 0)
            [_documentController setAnnotation:@{@"InstagramCaption" : _caption}];
        [_documentController presentOpenInMenuFromRect:self.view.frame inView:self.view animated:true];
    }];
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)__unused controller
{
    _documentController = nil;
}

#pragma mark -

- (void)dismiss
{
    if (self.overlayWindow != nil)
    {
        [super dismiss];
    }
    else
    {
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }
}

#pragma mark - Layout

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.view setNeedsLayout];
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[UIApplication sharedApplication].statusBarOrientation];
}

- (bool)inFormSheet
{
    if (iosMajorVersion() < 9)
        return [super inFormSheet];
    
    UIUserInterfaceSizeClass sizeClass = [UIApplication sharedApplication].delegate.window.rootViewController.traitCollection.horizontalSizeClass;
    if (sizeClass == UIUserInterfaceSizeClassCompact)
        return false;
    
    return [super inFormSheet];
}

- (CGSize)referenceViewSize
{
    if ([self inFormSheet])
        return CGSizeMake(540.0f, 620.0f);
    
    if (self.parentViewController != nil)
        return self.parentViewController.view.frame.size;
    else if (self.navigationController != nil)
        return self.navigationController.view.frame.size;
    
    return [UIScreen mainScreen].bounds.size;
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    bool isPad = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
    
    if ([self inFormSheet] || isPad)
        orientation = UIInterfaceOrientationPortrait;
    
    CGSize referenceSize = [self referenceViewSize];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height);
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    _containerView.frame = CGRectMake((screenSide - referenceSize.width) / 2, (screenSide - referenceSize.height) / 2, referenceSize.width, referenceSize.height);
    _transitionWrapperView.frame = _containerView.frame;
    
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - referenceSize.height) / 2, (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
    
    _landscapeToolbarView.interfaceOrientation = orientation;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolbarView.frame = CGRectMake(screenEdges.left, screenEdges.top, [_landscapeToolbarView landscapeSize], referenceSize.height);
            }];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolbarView.frame = CGRectMake(screenEdges.right - [_landscapeToolbarView landscapeSize], screenEdges.top, [_landscapeToolbarView landscapeSize], referenceSize.height);
            }];
        }
            break;
            
        default:
        {
            _landscapeToolbarView.frame = CGRectMake(_landscapeToolbarView.frame.origin.x, screenEdges.top, [_landscapeToolbarView landscapeSize], referenceSize.height);
        }
            break;
    }
    
    CGFloat portraitToolbarViewBottomEdge = screenSide;
    if (isPad)
        portraitToolbarViewBottomEdge = screenEdges.bottom;
    _portraitToolbarView.frame = CGRectMake(screenEdges.left, portraitToolbarViewBottomEdge - PhotoEditorToolbarSize, referenceSize.width, PhotoEditorToolbarSize);
}

- (void)_setScreenImage:(UIImage *)screenImage
{
    _screenImage = screenImage;
    if ([_currentTabController isKindOfClass:[PhotoAvatarCropController class]])
        [(PhotoAvatarCropController *)_currentTabController setSnapshotImage:screenImage];
}

- (void)_finishedTransitionIn
{
    _switchingTab = false;
    if ([_currentTabController isKindOfClass:[PhotoAvatarCropController class]])
        [(PhotoAvatarCropController *)_currentTabController _finishedTransitionIn];
}

- (CGFloat)toolbarLandscapeSize
{
    return _landscapeToolbarView.landscapeSize;
}

- (UIView *)transitionWrapperView
{
    return _transitionWrapperView;
}

- (void)setProgressVisible:(bool)progressVisible value:(CGFloat)value animated:(bool)animated
{
    _progressVisible = progressVisible;
    
    if (progressVisible && _progressView == nil)
    {
        _progressView = [[MessageImageViewOverlayView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 50.0f, 50.0f)];
        _progressView.userInteractionEnabled = false;
        
        _progressView.frame = (CGRect){{CGFloor((_wrapperView.frame.size.width - _progressView.frame.size.width) / 2.0f), CGFloor((_wrapperView.frame.size.height - _progressView.frame.size.height) / 2.0f)}, _progressView.frame.size};
    }
    
    if (progressVisible)
    {
        if (_progressView.superview == nil)
            [_wrapperView addSubview:_progressView];
        
        _progressView.alpha = 1.0f;
    }
    else if (_progressView.superview != nil)
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _progressView.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                    [_progressView removeFromSuperview];
            }];
        }
        else
            [_progressView removeFromSuperview];
    }
    
    [_progressView setProgress:value cancelEnabled:false animated:animated];
}

+ (PhotoEditorTab)defaultTabsForAvatarIntent
{
    static dispatch_once_t onceToken;
    static PhotoEditorTab avatarTabs = PhotoEditorNoneTab;
    dispatch_once(&onceToken, ^
    {
        if (iosMajorVersion() >= 7)
            avatarTabs = PhotoEditorCropTab | PhotoEditorToolsTab;
    });
    return avatarTabs;
}

@end
