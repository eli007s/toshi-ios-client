#import "CameraSegmentsView.h"
#import "CameraInterfaceAssets.h"

#import "ImageUtils.h"
#import "ModernButton.h"

const CGFloat CameraSegmentsBackgroundInset = 21.0f;
const CGFloat CameraSegmentsBackgroundHeight = 10.0f;
const CGFloat CameraSegmentsSpacing = 1.5f;
const CGFloat CameraSegmentsMinimumWidth = 4.0f;

@interface CameraSegmentView : UIImageView

- (void)setBlinking;
- (void)setRecording;
- (void)setCommittingWithCompletion:(void (^)(void))completion;

@end

@interface CameraSegmentsView ()
{
    UIImageView *_backgroundView;
    UIView *_segmentWrapper;
    NSArray *_segmentViews;
    
    CameraSegmentView *_currentSegmentView;
    CGFloat _currentSegment;
    
    ModernButton *_deleteButton;
}
@end

@implementation CameraSegmentsView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        static dispatch_once_t onceToken;
        static UIImage *segmentImage = nil;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, 4), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 4, 4) cornerRadius:0.5f] fill];
            segmentImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(4, 4, 4, 4)];
            UIGraphicsEndImageContext();
        });
        
        _backgroundView = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"CameraSegmentsBack"] resizableImageWithCapInsets:UIEdgeInsetsMake(4, 4, 4, 4)]];
        [self addSubview:_backgroundView];
        
        _segmentWrapper = [[UIView alloc] init];
        [_backgroundView addSubview:_segmentWrapper];
        
        _currentSegmentView = [[CameraSegmentView alloc] initWithImage:[TGTintedImage(segmentImage, [CameraInterfaceAssets accentColor]) resizableImageWithCapInsets:UIEdgeInsetsMake(4, 4, 4, 4)]];
        [_segmentWrapper addSubview:_currentSegmentView];
        
        _deleteButton = [[ModernButton alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
        _deleteButton.exclusiveTouch = true;
        [_deleteButton setImage:[UIImage imageNamed:@"CameraDeleteIcon"] forState:UIControlStateNormal];
        [_deleteButton addTarget:self action:@selector(deleteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_deleteButton];
        
        [self setDeleteButtonHidden:true animated:false];
    }
    return self;
}

- (void)deleteButtonPressed
{
    if (self.deletePressed != nil)
        self.deletePressed();
}

- (void)setSegments:(NSArray *)__unused segments
{
    
}

- (void)startCurrentSegment
{
    [_currentSegmentView setRecording];
}

- (void)setCurrentSegment:(CGFloat)length
{
    _currentSegment = length;
    [self _layoutSegmentViews];
}

- (void)commitCurrentSegmentWithCompletion:(void (^)(void))completion
{
    __weak CameraSegmentView *weakSegmentView = _currentSegmentView;
    [_currentSegmentView setCommittingWithCompletion:^
    {
        __strong CameraSegmentView *strongSegmentView = weakSegmentView;
        if (strongSegmentView == nil)
            return;
        
        _currentSegment = 0;
        
        if (completion != nil)
            completion();
        
        [strongSegmentView setBlinking];
    }];
}

- (void)highlightLastSegment
{
    
}

- (void)removeLastSegment
{
    
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
    
    if (!hidden)
        [_currentSegmentView setBlinking];
}

- (void)setHidden:(bool)hidden animated:(bool)animated delay:(NSTimeInterval)delay
{
    if (animated)
    {
        super.hidden = false;
        
        [UIView animateWithDuration:0.25f delay:delay options:UIViewAnimationOptionCurveLinear animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                self.hidden = hidden;
            
            if (!hidden)
                [_currentSegmentView setBlinking];
        }];
    }
    else
    {
        [self setHidden:hidden];
    }
}

- (void)setDeleteButtonHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        _deleteButton.hidden = false;
        
        [UIView animateWithDuration:0.25f animations:^
        {
            _deleteButton.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                _deleteButton.hidden = hidden;
        }];
    }
    else
    {
        _deleteButton.hidden = hidden;
        _deleteButton.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (void)_layoutBackgroundView
{
    CGFloat backgroundRightPadding = 0.0f;
    CGFloat deleteButtonMargin = _deleteButton.frame.size.width + 9.0f;
    if (!_deleteButton.hidden)
        backgroundRightPadding = deleteButtonMargin;
    
    _backgroundView.frame = CGRectMake(CameraSegmentsBackgroundInset, (self.frame.size.height - CameraSegmentsBackgroundHeight) / 2, self.frame.size.width - CameraSegmentsBackgroundInset * 2 - backgroundRightPadding, CameraSegmentsBackgroundHeight);
    _segmentWrapper.frame = CGRectMake(3, 3, self.frame.size.width - CameraSegmentsBackgroundInset * 2 - deleteButtonMargin, CameraSegmentsBackgroundHeight - 3 * 2);
}

- (void)_layoutDeleteButton
{
    _deleteButton.frame = CGRectMake(CGRectGetMaxX(_backgroundView.frame) + 14, (self.frame.size.height - _deleteButton.frame.size.height) / 2, _deleteButton.frame.size.width, _deleteButton.frame.size.height);
}

- (void)_layoutSegmentViews
{
    
}

- (void)layoutSubviews
{
    [self _layoutBackgroundView];
    [self _layoutDeleteButton];
}

@end

@interface CameraSegmentView ()
{
    
}
@end

@implementation CameraSegmentView

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super initWithImage:image];
    if (self != nil)
    {
        
    }
    return self;
}

- (void)setBlinking
{
    [self _playBlinkAnimation];
}

- (void)setRecording
{
    [self _stopBlinkAnimation];
}

- (void)setCommittingWithCompletion:(void (^)(void))__unused completion
{
    
}

- (void)_playBlinkAnimation
{
    CAKeyframeAnimation *blinkAnim = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    blinkAnim.duration = 1.2f;
    blinkAnim.autoreverses = false;
    blinkAnim.fillMode = kCAFillModeForwards;
    blinkAnim.repeatCount = HUGE_VALF;
    blinkAnim.keyTimes = @[ @0.0f, @0.4f, @0.5f, @0.9f, @1.0f ];
    blinkAnim.values = @[ @1.0f, @1.0f, @0.0f, @0.0f, @1.0f ];
    
    [self.layer addAnimation:blinkAnim forKey:@"opacity"];
}

- (void)_stopBlinkAnimation
{
    [self.layer removeAllAnimations];
}

@end
