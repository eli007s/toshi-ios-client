#import "MessageImageViewOverlayView.h"
#import "Color.h"
#import "ImageUtils.h"

#import <pop/POP.h>

typedef enum {
    MessageImageViewOverlayViewTypeNone = 0,
    MessageImageViewOverlayViewTypeDownload = 1,
    MessageImageViewOverlayViewTypeProgress = 2,
    MessageImageViewOverlayViewTypeProgressCancel = 3,
    MessageImageViewOverlayViewTypeProgressNoCancel = 4,
    MessageImageViewOverlayViewTypePlay = 5,
    MessageImageViewOverlayViewTypeSecret = 6,
    MessageImageViewOverlayViewTypeSecretViewed = 7,
    MessageImageViewOverlayViewTypeSecretProgress = 8,
    MessageImageViewOverlayViewTypePlayMedia = 9,
    MessageImageViewOverlayViewTypePauseMedia = 10
} MessageImageViewOverlayViewType;

@interface MessageImageViewOverlayLayer : CALayer
{
}

@property (nonatomic) CGFloat radius;
@property (nonatomic) int overlayStyle;
@property (nonatomic) CGFloat progress;
@property (nonatomic) int type;
@property (nonatomic, strong) UIColor *overlayBackgroundColorHint;

@property (nonatomic, strong) UIImage *blurredBackgroundImage;

@end

@implementation MessageImageViewOverlayLayer

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
    }
    return self;
}

- (void)setOverlayBackgroundColorHint:(UIColor *)overlayBackgroundColorHint
{
    if (_overlayBackgroundColorHint != overlayBackgroundColorHint)
    {
        _overlayBackgroundColorHint = overlayBackgroundColorHint;
        [self setNeedsDisplay];
    }
}

- (void)setOverlayStyle:(int)overlayStyle
{
    if (_overlayStyle != overlayStyle)
    {
        _overlayStyle = overlayStyle;
        [self setNeedsDisplay];
    }
}

- (void)setNone
{
    _type = MessageImageViewOverlayViewTypeNone;
    
    [self pop_removeAnimationForKey:@"progress"];
    [self pop_removeAnimationForKey:@"progressAmbient"];
    _progress = 0.0f;
}

- (void)setDownload
{
    if (_type != MessageImageViewOverlayViewTypeDownload)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = MessageImageViewOverlayViewTypeDownload;
        [self setNeedsDisplay];
    }
}

- (void)setPlay
{
    if (_type != MessageImageViewOverlayViewTypePlay)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = MessageImageViewOverlayViewTypePlay;
        [self setNeedsDisplay];
    }
}

- (void)setPlayMedia
{
    if (_type != MessageImageViewOverlayViewTypePlayMedia)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = MessageImageViewOverlayViewTypePlayMedia;
        [self setNeedsDisplay];
    }
}

- (void)setPauseMedia
{
    if (_type != MessageImageViewOverlayViewTypePauseMedia)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = MessageImageViewOverlayViewTypePauseMedia;
        [self setNeedsDisplay];
    }
}

- (void)setProgressCancel
{
    if (_type != MessageImageViewOverlayViewTypeProgressCancel)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = MessageImageViewOverlayViewTypeProgressCancel;
        [self setNeedsDisplay];
    }
}

- (void)setProgressNoCancel
{
    if (_type != MessageImageViewOverlayViewTypeProgressNoCancel)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = MessageImageViewOverlayViewTypeProgressNoCancel;
        [self setNeedsDisplay];
    }
}

- (void)setSecret:(bool)isViewed
{
    int newType = 0;
    if (isViewed)
        newType = MessageImageViewOverlayViewTypeSecretViewed;
    else
        newType = MessageImageViewOverlayViewTypeSecret;
    
    if (_type != newType)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = newType;
        [self setNeedsDisplay];
    }
}

- (void)setProgress:(CGFloat)progress
{
    _progress = progress;
    [self setNeedsDisplay];
}

+ (void)_addAmbientProgressAnimation:(MessageImageViewOverlayLayer *)layer
{
    POPBasicAnimation *ambientProgress = [self pop_animationForKey:@"progressAmbient"];
    
    ambientProgress = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerRotation];
    ambientProgress.fromValue = @((CGFloat)0.0f);
    ambientProgress.toValue = @((CGFloat)M_PI * 2.0f);
    ambientProgress.duration = 3.0;
    ambientProgress.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    ambientProgress.repeatForever = true;
    
    [layer pop_addAnimation:ambientProgress forKey:@"progressAmbient"];
}

- (void)setProgress:(CGFloat)progress animated:(bool)animated
{
    [self setProgress:progress animated:animated duration:0.5];
}

- (void)setProgress:(CGFloat)progress animated:(bool)animated duration:(NSTimeInterval)duration
{    
    if (_type != MessageImageViewOverlayViewTypeProgress || ABS(_progress - progress) > FLT_EPSILON)
    {
        if (_type != MessageImageViewOverlayViewTypeProgress)
            _progress = 0.0f;
        
        if ([self pop_animationForKey:@"progressAmbient"] == nil)
            [MessageImageViewOverlayLayer _addAmbientProgressAnimation:self];
        
        _type = MessageImageViewOverlayViewTypeProgress;
        
        if (animated)
        {
            POPBasicAnimation *animation = [self pop_animationForKey:@"progress"];
            if (animation != nil)
            {
                animation.toValue = @((CGFloat)progress);
            }
            else
            {
                animation = [POPBasicAnimation animation];
                animation.property = [POPAnimatableProperty propertyWithName:@"progress" initializer:^(POPMutableAnimatableProperty *prop)
                {
                    prop.readBlock = ^(MessageImageViewOverlayLayer *layer, CGFloat values[])
                    {
                        values[0] = layer.progress;
                    };
                    
                    prop.writeBlock = ^(MessageImageViewOverlayLayer *layer, const CGFloat values[])
                    {
                        layer.progress = values[0];
                    };
                    
                    prop.threshold = 0.01f;
                }];
                animation.fromValue = @(_progress);
                animation.toValue = @(progress);
                animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
                animation.duration = duration;
                [self pop_addAnimation:animation forKey:@"progress"];
            }
        }
        else
        {
            _progress = progress;
            
            [self setNeedsDisplay];
        }
    }
}

- (void)setSecretProgress:(CGFloat)progress completeDuration:(NSTimeInterval)completeDuration animated:(bool)animated
{
    if (_type != MessageImageViewOverlayViewTypeSecretProgress || ABS(_progress - progress) > FLT_EPSILON)
    {
        if (_type != MessageImageViewOverlayViewTypeSecretProgress)
        {
            _progress = 0.0f;
            [self setNeedsDisplay];
        }
        
        _type = MessageImageViewOverlayViewTypeSecretProgress;
        
        if (animated)
        {
            POPBasicAnimation *animation = [self pop_animationForKey:@"progress"];
            if (animation != nil)
            {
            }
            else
            {
                animation = [POPBasicAnimation animation];
                animation.property = [POPAnimatableProperty propertyWithName:@"progress" initializer:^(POPMutableAnimatableProperty *prop)
                {
                    prop.readBlock = ^(MessageImageViewOverlayLayer *layer, CGFloat values[])
                    {
                        values[0] = layer.progress;
                    };
                    
                    prop.writeBlock = ^(MessageImageViewOverlayLayer *layer, const CGFloat values[])
                    {
                        layer.progress = values[0];
                    };
                    
                    prop.threshold = 0.01f;
                }];
                animation.fromValue = @(_progress);
                animation.toValue = @(0.0);
                animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
                animation.duration = completeDuration * _progress;
                [self pop_addAnimation:animation forKey:@"progress"];
            }
        }
        else
        {
            _progress = progress;
            
            [self setNeedsDisplay];
        }
    }
}

- (void)drawInContext:(CGContextRef)context
{
    UIGraphicsPushContext(context);

    switch (_type)
    {
        case MessageImageViewOverlayViewTypeDownload:
        {
            CGFloat diameter = _overlayStyle == MessageImageViewOverlayStyleList ? 30.0f : self.radius;
            CGFloat lineWidth = _overlayStyle == MessageImageViewOverlayStyleList ? 1.4f : 2.0f;
            CGFloat height = _overlayStyle == MessageImageViewOverlayStyleList ? 18.0f : (ceil(self.radius / 2.0f) - 1.0f);
            CGFloat width = _overlayStyle == MessageImageViewOverlayStyleList ? 17.0f : ceil(self.radius / 2.5f);
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == MessageImageViewOverlayStyleDefault)
            {
                CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0xffffffff, 0.8f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleAccent)
            {
                CGContextSetStrokeColorWithColor(context, ColorWithHex(0xeaeaea).CGColor);
                CGContextSetLineWidth(context, 1.5f);
                CGContextStrokeEllipseInRect(context, CGRectMake(1.5f / 2.0f, 1.5f / 2.0f, diameter - 1.5f, diameter - 1.5f));
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleList)
            {
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleIncoming)
            {
                CGContextSetFillColorWithColor(context, TGAccentColor().CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleOutgoing)
            {
                CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0x3fc33b, 1.0f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            }
            
            if (_overlayStyle == MessageImageViewOverlayStyleDefault)
                CGContextSetStrokeColorWithColor(context, ColorWithHexAndAlpha(0xff000000, 0.55f).CGColor);
            else if (_overlayStyle == MessageImageViewOverlayStyleIncoming) {
                if (true || ABS(diameter - 37.0f) < 0.1) {
                    CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
                } else {
                    CGContextSetStrokeColorWithColor(context, ColorWithHex(0x4f9ef3).CGColor);
                }
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleOutgoing) {
                if (true || ABS(diameter - 37.0f) < 0.1) {
                    CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
                } else {
                    CGContextSetStrokeColorWithColor(context, ColorWithHex(0x64b15e).CGColor);
                }
            }
            else
                CGContextSetStrokeColorWithColor(context, TGAccentColor().CGColor);
            
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineWidth(context, lineWidth);
            
            CGPoint mainLine[] = {
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f, (diameter - height) / 2.0f + lineWidth / 2.0f),
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f, (diameter + height) / 2.0f - lineWidth / 2.0f)
            };
            
            CGPoint arrowLine[] = {
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f - width / 2.0f, (diameter + height) / 2.0f + lineWidth / 2.0f - width / 2.0f),
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f, (diameter + height) / 2.0f + lineWidth / 2.0f),
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f, (diameter + height) / 2.0f + lineWidth / 2.0f),
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f + width / 2.0f, (diameter + height) / 2.0f + lineWidth / 2.0f - width / 2.0f),
            };
            
            if (_overlayStyle == MessageImageViewOverlayStyleDefault)
                CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
            CGContextStrokeLineSegments(context, mainLine, sizeof(mainLine) / sizeof(mainLine[0]));
            CGContextStrokeLineSegments(context, arrowLine, sizeof(arrowLine) / sizeof(arrowLine[0]));
            
            if (_overlayStyle == MessageImageViewOverlayStyleDefault)
            {
                CGContextSetBlendMode(context, kCGBlendModeNormal);
                CGContextSetStrokeColorWithColor(context, ColorWithHexAndAlpha(0x000000, 0.55f).CGColor);
                CGContextStrokeLineSegments(context, arrowLine, sizeof(arrowLine) / sizeof(arrowLine[0]));
                
                CGContextSetBlendMode(context, kCGBlendModeCopy);
                CGContextStrokeLineSegments(context, mainLine, sizeof(mainLine) / sizeof(mainLine[0]));
            }
            
            break;
        }
        case MessageImageViewOverlayViewTypeProgressCancel:
        case MessageImageViewOverlayViewTypeProgressNoCancel:
        {
            CGFloat diameter = _overlayStyle == MessageImageViewOverlayStyleList ? 30.0f : self.radius;
            CGFloat inset = 0.0f;
            CGFloat lineWidth = _overlayStyle == MessageImageViewOverlayStyleList ? 1.5f : 2.0f;
            CGFloat crossSize = _overlayStyle == MessageImageViewOverlayStyleList ? 10.0f : 14.0f;
            
            if (ABS(diameter - 37.0f) < 0.1) {
                crossSize = 10.0f;
                inset = 2.0;
            }
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == MessageImageViewOverlayStyleDefault)
            {
                if (_overlayBackgroundColorHint != nil)
                    CGContextSetFillColorWithColor(context, _overlayBackgroundColorHint.CGColor);
                else
                    CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0x000000, 0.7f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(inset, inset, diameter - inset * 2.0f, diameter - inset * 2.0f));
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleIncoming)
            {
                if (true || ABS(diameter - 37.0f) < 0.1) {
                    CGContextSetFillColorWithColor(context, TGAccentColor().CGColor);
                } else {
                    CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0x85baf2, 0.15f).CGColor);
                }
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleOutgoing)
            {
                if (true || ABS(diameter - 37.0f) < 0.1) {
                    CGContextSetFillColorWithColor(context, ColorWithHex(0x3fc33b).CGColor);
                } else {
                    CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0x4fb212, 0.15f).CGColor);
                }
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleAccent)
            {
                CGContextSetStrokeColorWithColor(context, ColorWithHex(0xeaeaea).CGColor);
                CGContextSetLineWidth(context, 1.5f);
                CGContextStrokeEllipseInRect(context, CGRectMake(1.5f / 2.0f, 1.5f / 2.0f, diameter - 1.5f, diameter - 1.5f));
            }
            
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineWidth(context, lineWidth);
            
            CGPoint crossLine[] = {
                CGPointMake((diameter - crossSize) / 2.0f, (diameter - crossSize) / 2.0f),
                CGPointMake((diameter + crossSize) / 2.0f, (diameter + crossSize) / 2.0f),
                CGPointMake((diameter + crossSize) / 2.0f, (diameter - crossSize) / 2.0f),
                CGPointMake((diameter - crossSize) / 2.0f, (diameter + crossSize) / 2.0f),
            };
            
            if (_overlayStyle == MessageImageViewOverlayStyleDefault)
                CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
            else if (_overlayStyle == MessageImageViewOverlayStyleIncoming) {
                if (true || ABS(diameter - 37.0f) < 0.1) {
                    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
                } else {
                    CGContextSetStrokeColorWithColor(context, ColorWithHex(0x4f9ef3).CGColor);
                }
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleOutgoing) {
                if (true || ABS(diameter - 37.0f) < 0.1) {
                    CGContextSetStrokeColorWithColor(context, ColorWithHex(0xe1ffc7).CGColor);
                } else {
                    CGContextSetStrokeColorWithColor(context, ColorWithHex(0x64b15e).CGColor);
                }
            }
            else
                CGContextSetStrokeColorWithColor(context, TGAccentColor().CGColor);
            
            if (_type == MessageImageViewOverlayViewTypeProgressCancel)
                CGContextStrokeLineSegments(context, crossLine, sizeof(crossLine) / sizeof(crossLine[0]));
            
            if (_overlayStyle == MessageImageViewOverlayStyleDefault)
            {
                CGContextSetBlendMode(context, kCGBlendModeNormal);
                CGContextSetStrokeColorWithColor(context, ColorWithHexAndAlpha(0xffffff, 1.0f).CGColor);
                if (_type == MessageImageViewOverlayViewTypeProgressCancel)
                    CGContextStrokeLineSegments(context, crossLine, sizeof(crossLine) / sizeof(crossLine[0]));
            }
            
            break;
        }
        case MessageImageViewOverlayViewTypeProgress:
        {
            const CGFloat diameter = _overlayStyle == MessageImageViewOverlayStyleList ? 30.0f : self.radius;
            const CGFloat lineWidth = _overlayStyle == MessageImageViewOverlayStyleList ? 1.0f : 2.0f;
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineWidth(context, lineWidth);
            
            if (_overlayStyle == MessageImageViewOverlayStyleDefault)
                CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
            else if (_overlayStyle == MessageImageViewOverlayStyleIncoming) {
                if (true || ABS(diameter - 37.0f) < 0.1) {
                    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
                } else {
                    CGContextSetStrokeColorWithColor(context, ColorWithHex(0x4f9ef3).CGColor);
                }
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleOutgoing) {
                if (true || ABS(diameter - 37.0f) < 0.1) {
                    CGContextSetStrokeColorWithColor(context, ColorWithHex(0xe1ffc7).CGColor);
                } else {
                    CGContextSetStrokeColorWithColor(context, ColorWithHex(0x64b15e).CGColor);
                }
            }
            else
                CGContextSetStrokeColorWithColor(context, TGAccentColor().CGColor);
            
            if (_overlayStyle == MessageImageViewOverlayStyleDefault)
            {
                CGContextSetBlendMode(context, kCGBlendModeNormal);
                CGContextSetStrokeColorWithColor(context, ColorWithHexAndAlpha(0xffffff, 1.0f).CGColor);
            }
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            CGFloat start_angle = 2.0f * ((CGFloat)M_PI) * 0.0f - ((CGFloat)M_PI_2);
            CGFloat end_angle = 2.0f * ((CGFloat)M_PI) * _progress - ((CGFloat)M_PI_2);
            
            CGFloat pathLineWidth = _overlayStyle == MessageImageViewOverlayStyleDefault ? 2.0f : 2.0f;
            if (_overlayStyle == MessageImageViewOverlayStyleList)
                pathLineWidth = 1.4f;
            CGFloat pathDiameter = diameter - pathLineWidth;
            
            if (ABS(diameter - 37.0f) < 0.1) {
                pathLineWidth = 2.5f;
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5f;
            } else {
                pathLineWidth = 2.5f;
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5f;
            }
            
            UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(diameter / 2.0f, diameter / 2.0f) radius:pathDiameter / 2.0f startAngle:start_angle endAngle:end_angle clockwise:true];
            path.lineWidth = pathLineWidth;
            path.lineCapStyle = kCGLineCapRound;
            [path stroke];
            
            break;
        }
        case MessageImageViewOverlayViewTypePlay:
        {
            const CGFloat diameter = self.radius;
            CGFloat width = round(diameter * 0.4);
            CGFloat height = round(width * 1.2f);
            CGFloat offset = round(50.0f * 0.06f);
            CGFloat verticalOffset = 0.0f;
            CGFloat alpha = 0.8f;
            UIColor *iconColor = ColorWithHexAndAlpha(0xff000000, 0.45f);
            if (diameter <= 25.0f + FLT_EPSILON) {
                offset -= 1.0f;
                verticalOffset += 0.5f;
                alpha = 1.0f;
                iconColor = ColorWithHex(0x434344);
            }
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == MessageImageViewOverlayStyleIncoming)
            {
                CGContextSetFillColorWithColor(context, TGAccentColor().CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                UIImage *iconImage = [UIImage imageNamed:@"ModernMessageDocumentIconIncoming.png"];
                [iconImage drawAtPoint:CGPointMake(floor((diameter - iconImage.size.width) / 2.0f), floor((diameter - iconImage.size.height) / 2.0f)) blendMode:kCGBlendModeNormal alpha:1.0f];
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleOutgoing)
            {
                CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0x3fc33b, 1.0f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                UIImage *iconImage = [UIImage imageNamed:@"ModernMessageDocumentIconOutgoing.png"];
                [iconImage drawAtPoint:CGPointMake(floor((diameter - iconImage.size.width) / 2.0f), floor((diameter - iconImage.size.height) / 2.0f)) blendMode:kCGBlendModeNormal alpha:1.0f];
            }
            else
            {
                CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0xffffffff, alpha).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, offset + floor((diameter - width) / 2.0f), verticalOffset + floor((diameter - height) / 2.0f));
                CGContextAddLineToPoint(context, offset + floor((diameter - width) / 2.0f) + width, verticalOffset + floor(diameter / 2.0f));
                CGContextAddLineToPoint(context, offset + floor((diameter - width) / 2.0f), verticalOffset + floor((diameter + height) / 2.0f));
                CGContextClosePath(context);
                CGContextSetFillColorWithColor(context, iconColor.CGColor);
                CGContextFillPath(context);
            }
            
            break;
        }
        case MessageImageViewOverlayViewTypePlayMedia:
        {
            const CGFloat diameter = self.radius;
            const CGFloat width = 20.0f;
            const CGFloat height = width + 4.0f;
            const CGFloat offset = 3.0f;
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == MessageImageViewOverlayStyleIncoming)
            {
                CGContextSetFillColorWithColor(context, TGAccentColor().CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                CGContextSetBlendMode(context, kCGBlendModeCopy);
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                
                if (ABS(diameter - 37.0f) < 0.1) {
                    CGContextTranslateCTM(context, -TGRetinaPixel, TGRetinaPixel);
                    CGFloat factor = 28.0f / 34.0f;
                    CGContextScaleCTM(context, 0.5f * factor, 0.5f * factor);
                    
                    TGDrawSvgPath(context, @"M39.4267651,27.0560591 C37.534215,25.920529 36,26.7818508 36,28.9948438 L36,59.0051562 C36,61.2114475 37.4877047,62.0081969 39.3251488,60.7832341 L62.6748512,45.2167659 C64.5112802,43.9924799 64.4710515,42.0826309 62.5732349,40.9439409 L39.4267651,27.0560591 Z");
                } else {
                    CGContextBeginPath(context);
                    CGContextMoveToPoint(context, 17.0f, 13.0f);
                    CGContextAddLineToPoint(context, 32.0f, 22.0f);
                    CGContextAddLineToPoint(context, 17.0f, 32.0f);
                    CGContextClosePath(context);
                    CGContextFillPath(context);
                }
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleOutgoing)
            {
                CGContextSetFillColorWithColor(context, ColorWithHex(0x3fc33b).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                CGContextSetBlendMode(context, kCGBlendModeCopy);
                
                if (ABS(diameter - 37.0f) < 0.1) {
                    CGContextTranslateCTM(context, -TGRetinaPixel, TGRetinaPixel);
                    CGFloat factor = 28.0f / 34.0f;
                    CGContextScaleCTM(context, 0.5f * factor, 0.5f * factor);
                    
                    TGDrawSvgPath(context, @"M39.4267651,27.0560591 C37.534215,25.920529 36,26.7818508 36,28.9948438 L36,59.0051562 C36,61.2114475 37.4877047,62.0081969 39.3251488,60.7832341 L62.6748512,45.2167659 C64.5112802,43.9924799 64.4710515,42.0826309 62.5732349,40.9439409 L39.4267651,27.0560591 Z");
                } else {
                    CGContextBeginPath(context);
                    CGContextMoveToPoint(context, 17.0f, 13.0f);
                    CGContextAddLineToPoint(context, 32.0f, 22.0f);
                    CGContextAddLineToPoint(context, 17.0f, 32.0f);
                    CGContextClosePath(context);
                    CGContextFillPath(context);
                }
            }
            else
            {
                CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0xffffffff, 0.8f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, offset + floor((diameter - width) / 2.0f), floor((diameter - height) / 2.0f));
                CGContextAddLineToPoint(context, offset + floor((diameter - width) / 2.0f) + width, floor(diameter / 2.0f));
                CGContextAddLineToPoint(context, offset + floor((diameter - width) / 2.0f), floor((diameter + height) / 2.0f));
                CGContextClosePath(context);
                CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0xff000000, 0.45f).CGColor);
                CGContextFillPath(context);
            }
            
            break;
        }
        case MessageImageViewOverlayViewTypePauseMedia:
        {
            const CGFloat diameter = self.radius;
            const CGFloat width = 20.0f;
            const CGFloat height = width + 4.0f;
            const CGFloat offset = 3.0f;
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == MessageImageViewOverlayStyleIncoming)
            {
                CGContextSetFillColorWithColor(context, TGAccentColor().CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                CGContextSetBlendMode(context, kCGBlendModeCopy);
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                
                if (ABS(diameter - 37.0f) < 0.1) {
                    CGFloat factor = 28.0f / 34.0f;
                    CGContextTranslateCTM(context, TGRetinaPixel, TGRetinaPixel);
                    CGContextScaleCTM(context, 0.5f * factor, 0.5f * factor);
                    
                    TGDrawSvgPath(context, @"M29,30.0017433 C29,28.896211 29.8874333,28 30.999615,28 L37.000385,28 C38.1047419,28 39,28.8892617 39,30.0017433 L39,57.9982567 C39,59.103789 38.1125667,60 37.000385,60 L30.999615,60 C29.8952581,60 29,59.1107383 29,57.9982567 L29,30.0017433 Z M49,30.0017433 C49,28.896211 49.8874333,28 50.999615,28 L57.000385,28 C58.1047419,28 59,28.8892617 59,30.0017433 L59,57.9982567 C59,59.103789 58.1125667,60 57.000385,60 L50.999615,60 C49.8952581,60 49,59.1107383 49,57.9982567 L49,30.0017433 Z");
                } else {
                    CGContextFillRect(context, CGRectMake(15.5f, 14.5f, 4.0f, 15.0f));
                    CGContextFillRect(context, CGRectMake(24.5f, 14.5f, 4.0f, 15.0f));
                }
            }
            else if (_overlayStyle == MessageImageViewOverlayStyleOutgoing)
            {
                CGContextSetFillColorWithColor(context, ColorWithHex(0x3fc33b).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                
                if (ABS(diameter - 37.0f) < 0.1) {
                    CGFloat factor = 28.0f / 34.0f;
                    CGContextTranslateCTM(context, TGRetinaPixel, TGRetinaPixel);
                    CGContextScaleCTM(context, 0.5f * factor, 0.5f * factor);
                    
                    TGDrawSvgPath(context, @"M29,30.0017433 C29,28.896211 29.8874333,28 30.999615,28 L37.000385,28 C38.1047419,28 39,28.8892617 39,30.0017433 L39,57.9982567 C39,59.103789 38.1125667,60 37.000385,60 L30.999615,60 C29.8952581,60 29,59.1107383 29,57.9982567 L29,30.0017433 Z M49,30.0017433 C49,28.896211 49.8874333,28 50.999615,28 L57.000385,28 C58.1047419,28 59,28.8892617 59,30.0017433 L59,57.9982567 C59,59.103789 58.1125667,60 57.000385,60 L50.999615,60 C49.8952581,60 49,59.1107383 49,57.9982567 L49,30.0017433 Z");
                } else {
                    CGContextFillRect(context, CGRectMake(15.5f, 14.5f, 4.0f, 15.0f));
                    CGContextFillRect(context, CGRectMake(24.5f, 14.5f, 4.0f, 15.0f));
                }
            }
            else
            {
                CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0xffffffff, 0.8f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, offset + floor((diameter - width) / 2.0f), floor((diameter - height) / 2.0f));
                CGContextAddLineToPoint(context, offset + floor((diameter - width) / 2.0f) + width, floor(diameter / 2.0f));
                CGContextAddLineToPoint(context, offset + floor((diameter - width) / 2.0f), floor((diameter + height) / 2.0f));
                CGContextClosePath(context);
                CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0xff000000, 0.45f).CGColor);
                CGContextFillPath(context);
            }
            
            break;
        }
        case MessageImageViewOverlayViewTypeSecret:
        case MessageImageViewOverlayViewTypeSecretViewed:
        {
            const CGFloat diameter = self.radius;
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0xffffffff, 0.7f).CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            
            static UIImage *fireIconMask = nil;
            static UIImage *fireIcon = nil;
            static UIImage *viewedIconMask = nil;
            static UIImage *viewedIcon = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                fireIconMask = [UIImage imageNamed:@"SecretPhotoFireMask.png"];
                fireIcon = [UIImage imageNamed:@"SecretPhotoFire.png"];
                viewedIconMask = [UIImage imageNamed:@"SecretPhotoCheckMask.png"];
                viewedIcon = [UIImage imageNamed:@"SecretPhotoCheck.png"];
            });
            
            if (_type == MessageImageViewOverlayViewTypeSecret)
            {
                [fireIconMask drawAtPoint:CGPointMake(floor((diameter - fireIcon.size.width) / 2.0f), floor((diameter - fireIcon.size.height) / 2.0f)) blendMode:kCGBlendModeDestinationIn alpha:1.0f];
                [fireIcon drawAtPoint:CGPointMake(floor((diameter - fireIcon.size.width) / 2.0f), floor((diameter - fireIcon.size.height) / 2.0f)) blendMode:kCGBlendModeNormal alpha:0.4f];
            }
            else
            {
                CGPoint offset = CGPointMake(1.0f, 2.0f);
                [viewedIconMask drawAtPoint:CGPointMake(offset.x + floor((diameter - viewedIcon.size.width) / 2.0f), offset.y + floor((diameter - viewedIcon.size.height) / 2.0f)) blendMode:kCGBlendModeDestinationIn alpha:1.0f];
                [viewedIcon drawAtPoint:CGPointMake(offset.x + floor((diameter - viewedIcon.size.width) / 2.0f), offset.y + floor((diameter - viewedIcon.size.height) / 2.0f)) blendMode:kCGBlendModeNormal alpha:0.3f];
            }
            
            break;
        }
        case MessageImageViewOverlayViewTypeSecretProgress:
        {
            const CGFloat diameter = self.radius;
            
            [_blurredBackgroundImage drawInRect:CGRectMake(0.0f, 0.0f, diameter, diameter) blendMode:kCGBlendModeCopy alpha:1.0f];
            CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0xffffffff, 0.5f).CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            
            CGContextSetBlendMode(context, kCGBlendModeClear);
            
            CGContextSetFillColorWithColor(context, ColorWithHexAndAlpha(0xffffffff, 1.0f).CGColor);
            
            CGPoint center = CGPointMake(diameter / 2.0f, diameter / 2.0f);
            CGFloat radius = diameter / 2.0f + 0.25f;
            CGFloat startAngle = - ((CGFloat)M_PI / 2);
            CGFloat endAngle = ((1.0f - _progress) * 2 * (CGFloat)M_PI) + startAngle;
            CGContextMoveToPoint(context, center.x, center.y);
            CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0);
            CGContextClosePath(context);
            
            CGContextFillPath(context);
            
            break;
        }
        default:
            break;
    }
    
    UIGraphicsPopContext();
}

@end

@interface MessageImageViewOverlayView ()
{
    CALayer *_blurredBackgroundLayer;
    MessageImageViewOverlayLayer *_contentLayer;
    MessageImageViewOverlayLayer *_progressLayer;
}

@end

@implementation MessageImageViewOverlayView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = false;
        self.backgroundColor = [UIColor clearColor];
        
        _blurredBackgroundLayer = [[CALayer alloc] init];
        _blurredBackgroundLayer.frame = CGRectMake(0.5f + 0.125f, 0.5f + 0.125f, 50.0f - 0.25f - 1.0f, 50.0f - 0.25f - 1.0f);
        [self.layer addSublayer:_blurredBackgroundLayer];
        
        _contentLayer = [[MessageImageViewOverlayLayer alloc] init];
        _contentLayer.radius = 50.0f;
        _contentLayer.frame = CGRectMake(0.0f, 0.0f, 50.0f, 50.0f);
        _contentLayer.contentsScale = [UIScreen mainScreen].scale;
        [self.layer addSublayer:_contentLayer];
        
        _progressLayer = [[MessageImageViewOverlayLayer alloc] init];
        _progressLayer.radius = 50.0f;
        _progressLayer.frame = CGRectMake(0.0f, 0.0f, 50.0f, 50.0f);
        _progressLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
        _progressLayer.contentsScale = [UIScreen mainScreen].scale;
        _progressLayer.hidden = true;
        [self.layer addSublayer:_progressLayer];
    }
    return self;
}

- (void)setRadius:(CGFloat)radius
{
    _blurredBackgroundLayer.frame = CGRectMake(0.5f + 0.125f, 0.5f + 0.125f, radius - 0.25f - 1.0f, radius - 0.25f - 1.0f);
    _contentLayer.radius = radius;
    _contentLayer.frame = CGRectMake(0.0f, 0.0f, radius, radius);
    
    CATransform3D transform = _progressLayer.transform;
    _progressLayer.transform = CATransform3DIdentity;
    _progressLayer.radius = radius;
    _progressLayer.frame = CGRectMake(0.0f, 0.0f, radius, radius);
    _progressLayer.transform = transform;
}

- (void)setOverlayBackgroundColorHint:(UIColor *)overlayBackgroundColorHint
{
    [_contentLayer setOverlayBackgroundColorHint:overlayBackgroundColorHint];
}

- (void)setOverlayStyle:(MessageImageViewOverlayStyle)overlayStyle
{
    [_contentLayer setOverlayStyle:overlayStyle];
    [_progressLayer setOverlayStyle:overlayStyle];
    
    if (overlayStyle == MessageImageViewOverlayStyleList)
    {
        _contentLayer.frame = CGRectMake(0.0f, 0.0f, 30.0f, 30.0f);
        _progressLayer.frame = CGRectMake(0.0f, 0.0f, 30.0f, 30.0f);
        _progressLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
    }
    else
    {
        _contentLayer.frame = CGRectMake(0.0f, 0.0f, _contentLayer.radius, _contentLayer.radius);
        _progressLayer.frame = CGRectMake(0.0f, 0.0f, _progressLayer.radius, _progressLayer.radius);
        _progressLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
    }
}

- (void)setBlurredBackgroundImage:(UIImage *)blurredBackgroundImage
{
    _blurredBackgroundLayer.contents = (__bridge id)blurredBackgroundImage.CGImage;
    _contentLayer.blurredBackgroundImage = blurredBackgroundImage;
    if (_contentLayer.type == MessageImageViewOverlayViewTypeSecretProgress)
        [_contentLayer setNeedsDisplay];
}

- (void)setDownload
{
    [_contentLayer setDownload];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = false;
}

- (void)setPlay
{
    [_contentLayer setPlay];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = false;
}

- (void)setPlayMedia
{
    [_contentLayer setPlayMedia];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = false;
}

- (void)setPauseMedia
{
    [_contentLayer setPauseMedia];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = false;
}

- (void)setSecret:(bool)isViewed
{
    [_contentLayer setSecret:isViewed];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = false;
}

- (void)setNone
{
    [_contentLayer setNone];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = false;
}

- (void)setProgress:(CGFloat)progress animated:(bool)animated
{
    [self setProgress:progress cancelEnabled:true animated:animated];
}

- (void)setProgress:(CGFloat)progress cancelEnabled:(bool)cancelEnabled animated:(bool)animated
{
    if (progress > FLT_EPSILON)
        progress = MAX(progress, 0.027f);
    _blurredBackgroundLayer.hidden = false;
    _progressLayer.hidden = false;
    
    if (!animated)
    {
        _progressLayer.transform = CATransform3DIdentity;
        _progressLayer.frame = CGRectMake(0.0f, 0.0f, _contentLayer.frame.size.width, _contentLayer.frame.size.height);
    }
    
    _progress = progress;
    
    [_progressLayer setProgress:progress animated:animated];
    
    if (cancelEnabled)
        [_contentLayer setProgressCancel];
    else
        [_contentLayer setProgressNoCancel];
}

- (void)setProgressAnimated:(CGFloat)progress duration:(NSTimeInterval)duration cancelEnabled:(bool)cancelEnabled
{
    if (progress > FLT_EPSILON)
        progress = MAX(progress, 0.027f);
    _blurredBackgroundLayer.hidden = false;
    _progressLayer.hidden = false;
    
    _progress = progress;
    
    [_progressLayer setProgress:progress animated:true duration:duration];
    
    if (cancelEnabled)
        [_contentLayer setProgressCancel];
    else
        [_contentLayer setProgressNoCancel];
}

- (void)setSecretProgress:(CGFloat)progress completeDuration:(NSTimeInterval)completeDuration animated:(bool)animated
{
    _blurredBackgroundLayer.hidden = true;
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    [_contentLayer setSecretProgress:progress completeDuration:completeDuration animated:animated];
}

@end
