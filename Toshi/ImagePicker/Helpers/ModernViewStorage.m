#import "ModernViewStorage.h"
#import "Common.h"
#import "ModernView.h"

@interface ModernViewStorage ()
{
    NSMutableDictionary *_viewsByIdentifier;
    NSMutableDictionary *_resurrectionViewsByIdentifier;
    
    bool _resurrectionEnabled;
}

@end

@implementation ModernViewStorage

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _viewsByIdentifier = [[NSMutableDictionary alloc] init];
        _resurrectionViewsByIdentifier = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (UIView<ModernView> *)_dequeueViewFromQueues:(NSMutableDictionary *)queues withIdentifier:(NSString *)identifier viewStateIdentifier:(NSString *)viewStateIdentifier
{
    NSMutableArray *enqueuedViews = [queues objectForKey:identifier];
    if (enqueuedViews != nil)
    {
        UIView<ModernView> *view = nil;
        if (viewStateIdentifier != nil)
        {
            for (UIView<ModernView> *candidateView in enqueuedViews)
            {
                if (StringCompare(candidateView.viewStateIdentifier, viewStateIdentifier))
                {
                    //TGLog(@"(resurrected view %@:%@)", identifier, viewStateIdentifier);
                    view = candidateView;
                    break;
                }
            }
        }
        
        if (view == nil)
            view = [enqueuedViews lastObject];
        
        if (view != nil)
        {
            [enqueuedViews removeObject:view];
            return view;
        }
    }
    
    return nil;
}

- (UIView<ModernView> *)dequeueViewWithIdentifier:(NSString *)identifier viewStateIdentifier:(NSString *)viewStateIdentifier
{
    UIView<ModernView> *view = nil;
    if (_resurrectionViewsByIdentifier.count != 0)
        view = [self _dequeueViewFromQueues:_resurrectionViewsByIdentifier withIdentifier:identifier viewStateIdentifier:viewStateIdentifier];
    if (view == nil)
        view = [self _dequeueViewFromQueues:_viewsByIdentifier withIdentifier:identifier viewStateIdentifier:viewStateIdentifier];
    
    return view;
}

- (void)enqueueView:(UIView<ModernView> *)view
{
    NSString *identifier = [view viewIdentifier];
    if (identifier == nil)
    {
        TGLog(@"***** enqueueView: view doesn't have valid identifier");
        return;
    }
    
    NSMutableDictionary *concreteQueues = _resurrectionEnabled ? _resurrectionViewsByIdentifier : _viewsByIdentifier;
    
    NSMutableArray *enqueuedViews = [concreteQueues objectForKey:identifier];
    if (enqueuedViews == nil)
    {
        enqueuedViews = [[NSMutableArray alloc] init];
        [concreteQueues setObject:enqueuedViews forKey:identifier];
    }
    
    if (!_resurrectionEnabled)
        [view willBecomeRecycled];
    
    [enqueuedViews addObject:view];
}

- (void)allowResurrectionForOperations:(dispatch_block_t)block
{
    _resurrectionEnabled = true;
    
    block();
    
    _resurrectionEnabled = false;
    
    [_resurrectionViewsByIdentifier enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSArray *views, __unused BOOL *stop)
    {
        for (UIView<ModernView> *view in views)
        {
            [view willBecomeRecycled];
        }
        
        NSMutableArray *enqueuedViews = [_viewsByIdentifier objectForKey:identifier];
        if (enqueuedViews == nil)
        {
            enqueuedViews = [[NSMutableArray alloc] init];
            [_viewsByIdentifier setObject:enqueuedViews forKey:identifier];
        }
        
        [enqueuedViews addObjectsFromArray:views];
    }];
    
    [_resurrectionViewsByIdentifier removeAllObjects];
}

- (void)clear
{
    [_viewsByIdentifier removeAllObjects];
    [_resurrectionViewsByIdentifier removeAllObjects];
    _resurrectionEnabled = false;
}

@end
