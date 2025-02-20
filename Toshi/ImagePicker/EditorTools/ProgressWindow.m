#import "ProgressWindow.h"

#import "Common.h"

#import "OverlayControllerWindow.h"

@interface ProgressWindowController : TGOverlayWindowViewController

@property (nonatomic, weak) UIWindow *weakWindow;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;

@end

@implementation ProgressWindowController

- (void)loadView
{
    [super loadView];

    _containerView = [[UIView alloc] initWithFrame:CGRectMake(floor(self.view.frame.size.width - 100) / 2, floor(self.view.frame.size.height - 100) / 2, 100, 100)];
    _containerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    _containerView.alpha = 0.0f;
    [self.view addSubview:_containerView];
    
    UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:_containerView.bounds];
    UIImage *rawImage = [UIImage imageNamed:@"ProgressWindowBackground.png"];
    backgroundView.image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
    [_containerView addSubview:backgroundView];
    
    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicatorView.frame = CGRectOffset(_activityIndicatorView.frame, (int)((_containerView.frame.size.width - _activityIndicatorView.frame.size.width) / 2), (int)((_containerView.frame.size.height - _activityIndicatorView.frame.size.height) / 2));
    [_containerView addSubview:_activityIndicatorView];
    [_activityIndicatorView startAnimating];
}

- (void)show:(bool)animated
{
    UIWindow *window = _weakWindow;
    
    window.userInteractionEnabled = true;
    window.hidden = false;
    
    if (animated)
    {
        [UIView animateWithDuration:0.3f animations:^
        {
            _containerView.alpha = 1.0f;
        }];
    }
    else
        _containerView.alpha = 1.0f;
}

- (void)dismiss:(bool)animated
{
    ProgressWindow *window = (ProgressWindow *)_weakWindow;
    
    window.userInteractionEnabled = false;
    if (animated)
    {
        [UIView animateWithDuration:0.3f delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _containerView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                window.hidden = true;
                
                if (window.skipMakeKeyWindowOnDismiss)
                    return;
                
                NSArray *windows = [[UIApplication sharedApplication] windows];
                for (int i = (int)windows.count - 1; i >= 0; i--)
                {
                    if ([windows objectAtIndex:i] != window) {
                        [[windows objectAtIndex:i] makeKeyWindow];
                    }
                }
            }
        }];
    }
    else
    {
        _containerView.alpha = 0.0f;
        window.hidden = true;
        
        if (window.skipMakeKeyWindowOnDismiss)
            return;
        
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for (int i = (int)windows.count - 1; i >= 0; i--)
        {
            if ([windows objectAtIndex:i] != window) {
                [[windows objectAtIndex:i] makeKeyWindow];
            }
        }
    }
}

- (void)dismissWithSuccess
{
    ProgressWindow *window = (ProgressWindow *)_weakWindow;
    
    [_activityIndicatorView removeFromSuperview];
    window.userInteractionEnabled = false;
    
    UIImageView *checkView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ProgressWindowCheck.png"]];
    checkView.frame = CGRectOffset(checkView.frame, floor((_containerView.frame.size.width - checkView.frame.size.width) / 2), floor((_containerView.frame.size.height - checkView.frame.size.height) / 2));
    [_containerView addSubview:checkView];
    
    [UIView animateWithDuration:0.3 delay:0.5 options:0 animations:^
    {
        _containerView.alpha = 0.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            window.hidden = true;
            
            if (window.skipMakeKeyWindowOnDismiss)
                return;
            
            NSArray *windows = [[UIApplication sharedApplication] windows];
            for (int i = (int)windows.count - 1; i >= 0; i--)
            {
                if ([windows objectAtIndex:i] != window) {
                    [[windows objectAtIndex:i] makeKeyWindow];
                }
            }
        }
    }];
}

- (BOOL)canBecomeFirstResponder {
    return false;
}

@end

@interface ProgressWindow () {
    bool _dismissed;
}

@end

@implementation ProgressWindow

- (instancetype)init {
    return [self initWithFrame:[[UIScreen mainScreen] bounds]];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.windowLevel = UIWindowLevelStatusBar + 10000000.0f;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        ProgressWindowController *controller = [[ProgressWindowController alloc] init];;
        controller.weakWindow = self;
        self.rootViewController = controller;
        
        self.opaque = false;
    }
    return self;
}

- (void)showAnimated
{
    [self show:true];
}

- (void)showWithDelay:(NSTimeInterval)delay {
    __weak ProgressWindow *weakSelf = self;
    DispatchAfter(delay, dispatch_get_main_queue(), ^{
        __strong ProgressWindow *strongSelf = weakSelf;
        if (strongSelf != nil && !strongSelf->_dismissed) {
            [strongSelf show:true];
        }
    });
}

- (void)show:(bool)animated
{
    [((ProgressWindowController *)self.rootViewController) show:animated];
}

- (void)dismiss:(bool)animated
{
    if (!_dismissed) {
        _dismissed = true;
        self.userInteractionEnabled = false;
        
        [((ProgressWindowController *)self.rootViewController) dismiss:animated];
    }
}

- (void)dismissWithSuccess
{
    if (!_dismissed) {
        _dismissed = true;
        [self show:false];
        [((ProgressWindowController *)self.rootViewController) dismissWithSuccess];
    }
}

@end
