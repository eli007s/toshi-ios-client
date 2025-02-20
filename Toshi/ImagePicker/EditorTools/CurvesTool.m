#import "CurvesTool.h"
#import "PhotoEditorCurvesToolView.h"
#import "PhotoEditorCurvesHistogramView.h"
#import "Common.h"

const NSUInteger PGCurveGranularity = 100;
const NSUInteger PGCurveDataStep = 2;

@interface CurvesValue ()
{
    NSArray *_cachedDataPoints;
}
@end

@implementation CurvesValue

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    CurvesValue *value = [[CurvesValue alloc] init];
    value.blacksLevel = self.blacksLevel;
    value.shadowsLevel = self.shadowsLevel;
    value.midtonesLevel = self.midtonesLevel;
    value.highlightsLevel = self.highlightsLevel;
    value.whitesLevel = self.whitesLevel;
    
    return value;
}

+ (instancetype)defaultValue
{
    CurvesValue *value = [[CurvesValue alloc] init];
    value.blacksLevel = 0;
    value.shadowsLevel = 25;
    value.midtonesLevel = 50;
    value.highlightsLevel = 75;
    value.whitesLevel = 100;
    
    return value;
}

- (NSArray *)dataPoints
{
    if (_cachedDataPoints == nil)
        [self interpolateCurve];
    
    return _cachedDataPoints;
}

- (bool)isDefault
{
    if (fabs(self.blacksLevel - 0) < FLT_EPSILON
        && fabs(self.shadowsLevel - 25) < FLT_EPSILON
        && fabs(self.midtonesLevel - 50) < FLT_EPSILON
        && fabs(self.highlightsLevel - 75) < FLT_EPSILON
        && fabs(self.whitesLevel - 100) < FLT_EPSILON)
    {
        return true;
    }
    
    return false;
}

- (NSArray *)interpolateCurve
{
    NSMutableArray *points = [[NSMutableArray alloc] init];
    [points addObject:[NSValue valueWithCGPoint:CGPointMake(-0.001, self.blacksLevel / 100.0)]];
    [points addObject:[NSValue valueWithCGPoint:CGPointMake(0.0, self.blacksLevel / 100.0)]];
    [points addObject:[NSValue valueWithCGPoint:CGPointMake(0.25, self.shadowsLevel / 100.0)]];
    [points addObject:[NSValue valueWithCGPoint:CGPointMake(0.5, self.midtonesLevel / 100.0)]];
    [points addObject:[NSValue valueWithCGPoint:CGPointMake(0.75, self.highlightsLevel / 100.0)]];
    [points addObject:[NSValue valueWithCGPoint:CGPointMake(1, self.whitesLevel / 100.0)]];
    [points addObject:[NSValue valueWithCGPoint:CGPointMake(1.001, self.whitesLevel / 100.0)]];
 
    NSMutableArray *dataPoints = [[NSMutableArray alloc] init];
    
    NSMutableArray *interpolatedPoints = [[NSMutableArray alloc] init];
    [interpolatedPoints addObject:points.firstObject];
    
    for (NSUInteger index = 1; index < points.count - 2; index++)
    {
        CGPoint point0 = [points[index - 1] CGPointValue];
        CGPoint point1 = [points[index] CGPointValue];
        CGPoint point2 = [points[index + 1] CGPointValue];
        CGPoint point3 = [points[index + 2] CGPointValue];
        
        for (NSUInteger i = 1; i < PGCurveGranularity; i++)
        {
            CGFloat t = (CGFloat)i * (1.0f / (CGFloat)PGCurveGranularity);
            CGFloat tt = t * t;
            CGFloat ttt = tt * t;
            
            CGPoint pi =
            {
                0.5 * (2 * point1.x + (point2.x - point0.x) * t + (2 * point0.x - 5 * point1.x + 4 * point2.x - point3.x) * tt + (3 * point1.x - point0.x - 3 * point2.x + point3.x) * ttt),
                0.5 * (2 * point1.y + (point2.y - point0.y) * t + (2 * point0.y - 5 * point1.y + 4 * point2.y - point3.y) * tt + (3 * point1.y - point0.y - 3 * point2.y + point3.y) * ttt)
            };
            
            pi.y = MAX(0, MIN(1, pi.y));
            
            if (pi.x > point0.x)
                [interpolatedPoints addObject:[NSValue valueWithCGPoint:pi]];
            
            if ((i - 1) % PGCurveDataStep == 0)
                [dataPoints addObject:@(pi.y)];
        }
        
        [interpolatedPoints addObject:[NSValue valueWithCGPoint:point2]];
    }
    
    [interpolatedPoints addObject:points.lastObject];
    
    _cachedDataPoints = dataPoints;
    
    return interpolatedPoints;
}

@end

@implementation CurvesToolValue

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    CurvesToolValue *value = [[CurvesToolValue alloc] init];
    value.luminanceCurve = [self.luminanceCurve copy];
    value.redCurve = [self.redCurve copy];
    value.greenCurve = [self.greenCurve copy];
    value.blueCurve = [self.blueCurve copy];
    value.activeType = self.activeType;
    
    return value;
}

+ (instancetype)defaultValue
{
    CurvesToolValue *value = [[CurvesToolValue alloc] init];
    value.luminanceCurve = [CurvesValue defaultValue];
    value.redCurve = [CurvesValue defaultValue];
    value.greenCurve = [CurvesValue defaultValue];
    value.blueCurve = [CurvesValue defaultValue];
    value.activeType = PGCurvesTypeLuminance;
    
    return value;
}

- (id<CustomToolValue>)cleanValue
{
    CurvesToolValue *value = [[CurvesToolValue alloc] init];
    value.luminanceCurve = [self.luminanceCurve copy];
    value.redCurve = [self.redCurve copy];
    value.greenCurve = [self.greenCurve copy];
    value.blueCurve = [self.blueCurve copy];
    value.activeType = PGCurvesTypeLuminance;
    
    return value;
}

@end


@interface CurvesTool ()
{
    PhotoProcessPassParameter *_rgbCurveParameter;
    PhotoProcessPassParameter *_redCurveParameter;
    PhotoProcessPassParameter *_greenCurveParameter;
    PhotoProcessPassParameter *_blueCurveParameter;
    
    PhotoProcessPassParameter *_skipToneParameter;
}
@end

@implementation CurvesTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"curves";
        _type = PhotoToolTypeShader;
        _order = 1;
        
        _minimumValue = 0;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = [CurvesToolValue defaultValue];
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"CurvesTool");
}

- (UIImage *)image
{
    return [UIImage imageNamed:@"PhotoEditorCurvesTool"];
}

- (UIView <PhotoEditorToolView> *)itemAreaViewWithChangeBlock:(void (^)(id))changeBlock
{
    __weak CurvesTool *weakSelf = self;
    
    UIView <PhotoEditorToolView> *view = [[PhotoEditorCurvesToolView alloc] initWithEditorItem:self];
    view.valueChanged = ^(id newValue, __unused bool animated)
    {
        __strong PhotoTool *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (newValue != nil)
        {
            if ([strongSelf.tempValue isEqual:newValue])
                return;
            
            strongSelf.tempValue = newValue;
        }
        
        if (changeBlock != nil)
            changeBlock(newValue);
    };
    return view;
}

- (UIView <PhotoEditorToolView> *)itemControlViewWithChangeBlock:(void (^)(id, bool))__unused changeBlock
{
    __weak CurvesTool *weakSelf = self;
    
    UIView <PhotoEditorToolView> *view = [[PhotoEditorCurvesHistogramView alloc] initWithEditorItem:self];
    view.valueChanged = ^(id newValue, __unused bool animated)
    {
        __strong PhotoTool *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (newValue != nil)
        {
            if ([strongSelf.tempValue isEqual:newValue])
                return;
            
            strongSelf.tempValue = newValue;
        }
        
        if (changeBlock != nil)
            changeBlock(newValue, false);
    };
    
    return view;
}

- (Class)valueClass
{
    return [CurvesToolValue class];
}

- (bool)shouldBeSkipped
{
    CurvesToolValue *value = (CurvesToolValue *)self.displayValue;
    return [value.luminanceCurve isDefault] && [value.redCurve isDefault] && [value.greenCurve isDefault] && [value.blueCurve isDefault];
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        NSInteger count = PGCurveGranularity * PGCurveDataStep;
        _rgbCurveParameter = [PhotoProcessPassParameter parameterWithName:@"rgbCurveValues" type:@"lowp float" count:count];
        _redCurveParameter = [PhotoProcessPassParameter parameterWithName:@"redCurveValues" type:@"lowp float" count:count];
        _greenCurveParameter = [PhotoProcessPassParameter parameterWithName:@"greenCurveValues" type:@"lowp float" count:count];
        _blueCurveParameter = [PhotoProcessPassParameter parameterWithName:@"blueCurveValues" type:@"lowp float" count:count];
        _skipToneParameter = [PhotoProcessPassParameter parameterWithName:@"skipTone" type:@"lowp float"];
        
        _parameters = @[ _rgbCurveParameter, _redCurveParameter, _greenCurveParameter, _blueCurveParameter, _skipToneParameter ];
    }

    return _parameters;
}

- (void)updateParameters
{
    CurvesToolValue *value = (CurvesToolValue *)self.displayValue;
    
    [_rgbCurveParameter setFloatArray:[value.luminanceCurve dataPoints]];
    [_redCurveParameter setFloatArray:[value.redCurve dataPoints]];
    [_greenCurveParameter setFloatArray:[value.greenCurve dataPoints]];
    [_blueCurveParameter setFloatArray:[value.blueCurve dataPoints]];
    
    [_skipToneParameter setFloatValue:self.shouldBeSkipped ? 1.0 : 0.0];
}

- (NSString *)ancillaryShaderString
{
    return PGShaderString
    (
     lowp vec3 applyLuminanceCurve(lowp vec3 pixel) {
         int index = int(clamp(pixel.z / (1.0 / 200.0), 0.0, 199.0));
         highp float value = rgbCurveValues[index];
         
         highp float grayscale = (smoothstep(0.0, 0.1, pixel.z) * (1.0 - smoothstep(0.8, 1.0, pixel.z)));
         highp float saturation = mix(0.0, pixel.y, grayscale);
         pixel.y = saturation;
         pixel.z = value;
         return pixel;
     }
     
     lowp vec3 applyRGBCurve(lowp vec3 pixel) {
         int index = int(clamp(pixel.r / (1.0 / 200.0), 0.0, 199.0));
         highp float value = redCurveValues[index];
         pixel.r = value;
         
         index = int(clamp(pixel.g / (1.0 / 200.0), 0.0, 199.0));
         value = greenCurveValues[index];
         pixel.g = clamp(value, 0.0, 1.0);
         
         index = int(clamp(pixel.b / (1.0 / 200.0), 0.0, 199.0));
         value = blueCurveValues[index];
         pixel.b = clamp(value, 0.0, 1.0);
         
         return pixel;
     }
    );
}

- (NSString *)stringValue
{
    if (![self shouldBeSkipped])
    {
        return @"◆";
    }
    
    return nil;
}

- (NSString *)shaderString
{
    return PGShaderString
    (
     if (skipTone < toolEpsilon) {
        result = vec4(applyRGBCurve(hslToRgb(applyLuminanceCurve(rgbToHsl(result.rgb)))), result.a);
     }
    );
}

@end
