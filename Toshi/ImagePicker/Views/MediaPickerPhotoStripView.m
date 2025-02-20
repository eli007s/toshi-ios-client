#import "MediaPickerPhotoStripView.h"

#import <pop/POP.h>

#import "PhotoEditorInterfaceAssets.h"

#import "PhotoEditorUtils.h"

#import "DraggableCollectionView.h"
#import "DraggableCollectionViewFlowLayout.h"

#import "MediaPickerPhotoStripCell.h"

#import "MediaPickerGallerySelectedItemsModel.h"

const CGSize MediaPickerSelectedPhotosViewArrowSize = { 19, 8.5f };

@interface MediaPickerPhotoStripView () <DraggableCollectionViewDataSource, UICollectionViewDelegate>
{
    UIView *_wrapperView;
    UIImageView *_backgroundView;
    UIImageView *_arrowView;
    UIView *_maskView;
    DraggableCollectionView *_collectionView;
    DraggableCollectionViewFlowLayout *_collectionViewLayout;
}
@end

@implementation MediaPickerPhotoStripView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {        
        static UIImage *background = nil;
        static UIImage *arrow = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(6, 6), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, [PhotoEditorInterfaceAssets selectedImagesPanelBackgroundColor].CGColor);

            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 6, 6)
                                                          cornerRadius:2];
            [path fill];
            background = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(3, 3, 3, 3)];
            UIGraphicsEndImageContext();
            
            UIGraphicsBeginImageContextWithOptions(MediaPickerSelectedPhotosViewArrowSize, false, 0.0f);
            context = UIGraphicsGetCurrentContext();
            
            CGContextBeginPath(context);
            CGContextSetFillColorWithColor(context, [PhotoEditorInterfaceAssets selectedImagesPanelBackgroundColor].CGColor);
            CGContextMoveToPoint(context, MediaPickerSelectedPhotosViewArrowSize.width / 2.0f, 0);
            CGContextAddLineToPoint(context, MediaPickerSelectedPhotosViewArrowSize.width, MediaPickerSelectedPhotosViewArrowSize.height);
            CGContextAddLineToPoint(context, 0, MediaPickerSelectedPhotosViewArrowSize.height);
            CGContextClosePath(context);
            CGContextFillPath(context);

            arrow = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _wrapperView = [[UIView alloc] initWithFrame:self.bounds];
        _wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_wrapperView];
        
        _backgroundView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _backgroundView.image = background;
        [_wrapperView addSubview:_backgroundView];
        
        _arrowView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _arrowView.image = arrow;
        //[_wrapperView addSubview:_arrowView];
        
        _maskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _maskView.clipsToBounds = true;
        [_wrapperView addSubview:_maskView];
        
        _collectionViewLayout = [[DraggableCollectionViewFlowLayout alloc] init];
        _collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _collectionViewLayout.itemSize = PhotoThumbnailSizeForCurrentScreen();
        _collectionViewLayout.minimumInteritemSpacing = 2.5f;
        _collectionViewLayout.minimumLineSpacing = 2.5f;
        
        _collectionView = [[DraggableCollectionView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height) collectionViewLayout:_collectionViewLayout];
        _collectionView.alwaysBounceHorizontal = false;
        _collectionView.alwaysBounceVertical = false;
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.draggable = false;
        _collectionView.draggedViewSuperview = self;
        _collectionView.showsHorizontalScrollIndicator = false;
        _collectionView.showsVerticalScrollIndicator = false;
        [_collectionView registerClass:[MediaPickerPhotoStripCell class] forCellWithReuseIdentifier:MediaPickerPhotoStripCellKind];
        [_maskView addSubview:_collectionView];
        
        CGFloat draggingInset = 40.0f + _collectionViewLayout.itemSize.width / 2;
        _collectionView.scrollingTriggerEdgeInsets = UIEdgeInsetsMake(draggingInset, draggingInset, draggingInset, draggingInset);
    }
    return self;
}

- (void)dealloc
{
    _collectionView.dataSource = nil;
    _collectionView.delegate = nil;
}

#pragma mark - Update

- (void)reloadData
{
    [_collectionView reloadData];
    [self setNeedsLayout];
}

- (void)insertItemAtIndex:(NSInteger)index
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    
    [UIView performWithoutAnimation:^
    {
        [_collectionView performBatchUpdates:^
        {
            [_collectionView insertItemsAtIndexPaths:@[ indexPath ]];
        } completion:^(__unused BOOL finished)
        {
            [UIView animateWithDuration:0.3f
                             animations:^
            {
                [self _layoutCollectionViewForOrientation:self.interfaceOrientation];
            }];
            
            if (_collectionViewLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal)
            {
                [_collectionView setContentOffset:CGPointMake(_collectionView.contentSize.width - _collectionView.frame.size.width + _collectionView.contentInset.left, _collectionView.contentOffset.y) animated:true];
            }
            else
            {
                [_collectionView setContentOffset:CGPointMake(_collectionView.contentOffset.x, _collectionView.contentSize.height - _collectionView.frame.size.height + _collectionView.contentInset.top) animated:true];
            }
        }];
    }];
}

- (void)deleteItemAtIndex:(NSInteger)index
{
    [_collectionView performBatchUpdates:^
    {
        [_collectionView deleteItemsAtIndexPaths:@[ [NSIndexPath indexPathForRow:index inSection:0] ]];
    } completion:nil];
    
    [UIView animateWithDuration:0.3f
                     animations:^
    {
        [self _layoutCollectionViewForOrientation:self.interfaceOrientation];
        
        NSInteger itemsCount = [self collectionView:_collectionView numberOfItemsInSection:0];
        if (itemsCount > 0 && itemsCount < 4)
        {
            NSIndexPath *previousIndexPath = [NSIndexPath indexPathForRow:itemsCount - 1 inSection:0];
            if (_collectionViewLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal)
                [_collectionView scrollToItemAtIndexPath:previousIndexPath atScrollPosition:UICollectionViewScrollPositionRight animated:false];
            else
                [_collectionView scrollToItemAtIndexPath:previousIndexPath atScrollPosition:UICollectionViewScrollPositionBottom animated:false];
        }
    }];
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        self.hidden = false;
        
        if (hidden)
        {
            if ([_wrapperView.pop_animationKeys containsObject:@"hide_opacity"] || [_wrapperView.pop_animationKeys containsObject:@"hide_center"])
                return;
            
            [_wrapperView pop_removeAllAnimations];
            
            POPSpringAnimation *opacityAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewAlpha];
            opacityAnimation.springSpeed = 12;
            opacityAnimation.springBounciness = 7;
            opacityAnimation.fromValue = @(_wrapperView.alpha);
            opacityAnimation.toValue = @0;
            opacityAnimation.completionBlock = ^(__unused POPAnimation *animation, BOOL finished)
            {
                if (finished)
                {
                    self.hidden = true;
                    [self stopScrolling];
                }
            };
            [_wrapperView pop_addAnimation:opacityAnimation forKey:@"hide_opacity"];
            
            POPSpringAnimation *centerAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewCenter];
            centerAnimation.springSpeed = 12;
            centerAnimation.springBounciness = 7;
            centerAnimation.fromValue = [NSValue valueWithCGPoint:_wrapperView.center];
            if (self.interfaceOrientation == UIInterfaceOrientationPortrait)
            {
                centerAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(self.frame.size.width / 2,
                                                                                self.frame.size.height / 2 + self.frame.size.height / 3)];
            }
            else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                centerAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(self.frame.size.width / 2 - self.frame.size.width / 3,
                                                                                self.frame.size.height / 2)];
            }
            else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
            {
                centerAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(self.frame.size.width / 2 + self.frame.size.width / 3,
                                                                                self.frame.size.height / 2)];
            }
            [_wrapperView pop_addAnimation:centerAnimation forKey:@"hide_center"];
        }
        else
        {
            if ([_wrapperView.pop_animationKeys containsObject:@"show_opacity"] || [_wrapperView.pop_animationKeys containsObject:@"show_center"])
                return;
            
            [_wrapperView pop_removeAllAnimations];
            
            POPSpringAnimation *opacityAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewAlpha];
            opacityAnimation.springSpeed = 12;
            opacityAnimation.springBounciness = 7;
            opacityAnimation.fromValue = @(_wrapperView.alpha);
            opacityAnimation.toValue = @1;
            [_wrapperView pop_addAnimation:opacityAnimation forKey:@"show_opacity"];
            
            POPSpringAnimation *centerAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewCenter];
            centerAnimation.springSpeed = 12;
            centerAnimation.springBounciness = 7;
            centerAnimation.fromValue = [NSValue valueWithCGPoint:_wrapperView.center];
            centerAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2)];
            [_wrapperView pop_addAnimation:centerAnimation forKey:@"show_center"];
        }
    }
    else
    {
        self.hidden = hidden;
        _wrapperView.alpha = hidden ? 0.0f : 1.0f;
        
        if (hidden)
        {
            if (self.interfaceOrientation == UIInterfaceOrientationPortrait)
            {
                _wrapperView.center = CGPointMake(self.frame.size.width / 2,
                                                  self.frame.size.height / 2 + self.frame.size.height / 3);
            }
            else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                _wrapperView.center = CGPointMake(self.frame.size.width / 2 - self.frame.size.width / 3,
                                                  self.frame.size.height / 2);
            }
            else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
            {
                _wrapperView.center = CGPointMake(self.frame.size.width / 2 + self.frame.size.width / 3,
                                                  self.frame.size.height / 2);
            }
        }
        else
        {
            _wrapperView.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        }
    }
}

- (void)stopScrolling
{
    CGPoint contentOffset = _collectionView.contentOffset;
    
    if (_collectionViewLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal)
    {
        contentOffset.x = MAX(-_collectionView.contentInset.left, MIN(_collectionView.contentOffset.x - 0.001f, _collectionView.contentSize.width - _collectionView.frame.size.width + _collectionView.contentInset.left));
    }
    else
    {
        contentOffset.y = MAX(-_collectionView.contentInset.top, MIN(_collectionView.contentOffset.y - 0.001f, _collectionView.contentSize.height - _collectionView.frame.size.height + _collectionView.contentInset.top));
    }
    
    [_collectionView setContentOffset:contentOffset animated:false];
}

#pragma mark - Collection View Data Source & Delegate

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id item = _selectedItemsModel.items[indexPath.row];
    
    __weak MediaPickerPhotoStripView *weakSelf = self;
    MediaPickerPhotoStripCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:MediaPickerPhotoStripCellKind forIndexPath:indexPath];
    cell.selectionContext = self.selectionContext;
    cell.editingContext = self.editingContext;
    cell.itemSelected = ^(id<MediaSelectableItem> item, bool selected, __unused id sender)
    {
        __strong MediaPickerPhotoStripView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf.selectionContext setItem:item selected:selected animated:true sender:strongSelf.selectedItemsModel];
    };
    [cell setItem:item signal:self.thumbnailSignalForItem(item)];

    return cell;
}

- (void)collectionView:(UICollectionView *)__unused collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.itemSelected != nil)
        self.itemSelected(indexPath.row);
    
    UICollectionViewCell *cell = [_collectionView cellForItemAtIndexPath:indexPath];
    CGRect frame = [_collectionView convertRect:cell.frame toView:_collectionView.superview];
    
    if (self.frame.size.width > self.frame.size.height)
    {
        if (CGRectGetMinX(frame) < 0)
            [_collectionView setContentOffset:CGPointMake(_collectionView.contentOffset.x + frame.origin.x, _collectionView.contentOffset.y) animated:true];
        else if (CGRectGetMaxX(frame) > _collectionView.superview.frame.size.width)
            [_collectionView setContentOffset:CGPointMake(_collectionView.contentOffset.x + CGRectGetMaxX(frame) - _collectionView.superview.frame.size.width, _collectionView.contentOffset.y) animated:true];
    }
    else
    {
        if (CGRectGetMinY(frame) < 0)
            [_collectionView setContentOffset:CGPointMake(_collectionView.contentOffset.x, _collectionView.contentOffset.y + frame.origin.y) animated:true];
        else if (CGRectGetMaxY(frame) > _collectionView.superview.frame.size.height)
            [_collectionView setContentOffset:CGPointMake(_collectionView.contentOffset.x, _collectionView.contentOffset.y + CGRectGetMaxY(frame) - _collectionView.superview.frame.size.height) animated:true];
    }
}

- (NSInteger)collectionView:(UICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)__unused section
{
    MediaPickerGallerySelectedItemsModel *selectedItemsModel = self.selectedItemsModel;
    return selectedItemsModel.totalCount;
}

- (bool)collectionView:(UICollectionView *)__unused collectionView canMoveItemAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return false;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout*)__unused collectionViewLayout insetForSectionAtIndex:(NSInteger)__unused section
{
    return UIEdgeInsetsMake(40, 40, 40, 40);
}

- (void)scrollViewDidScroll:(UIScrollView *)__unused scrollView
{
    if (_collectionViewLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal)
    {
        if (_collectionView.contentSize.width > _collectionView.frame.size.width - _collectionView.contentInset.left - _collectionView.contentInset.right)
        {
            if (_collectionView.contentOffset.x < -_collectionView.contentInset.left)
            {
                CGFloat offset = -_collectionView.contentOffset.x - _collectionView.contentInset.left;
                _backgroundView.frame = CGRectMake(self.frame.size.width - _backgroundView.frame.size.width + offset, 0, _backgroundView.frame.size.width, self.frame.size.height);
                _maskView.frame = CGRectMake(_maskView.frame.origin.x, _maskView.frame.origin.y, _backgroundView.frame.size.width - 8 + MIN(8, offset), _maskView.frame.size.height);
                return;
            }
            else if (_collectionView.contentOffset.x + _collectionView.frame.size.width > _collectionView.contentSize.width + _collectionView.contentInset.right)
            {
                CGFloat offset = (_collectionView.contentSize.width - _collectionView.frame.size.width - _collectionView.contentOffset.x + _collectionView.contentInset.right);
                _backgroundView.frame = CGRectMake(self.frame.size.width - _backgroundView.frame.size.width + offset + MAX(-8, offset * 2), 0, _backgroundView.frame.size.width, self.frame.size.height);
                _maskView.frame = CGRectMake(self.frame.size.width - _backgroundView.frame.size.width + 4 - MIN(8, -offset * 2), _maskView.frame.origin.y, _maskView.frame.size.width, _maskView.frame.size.height);
                return;
            }
        }

        _backgroundView.frame = CGRectMake(self.frame.size.width - _backgroundView.frame.size.width, 0, _backgroundView.frame.size.width, self.frame.size.height);
        _maskView.frame = CGRectMake(_backgroundView.frame.origin.x + 4, _backgroundView.frame.origin.y + 4, _backgroundView.frame.size.width - 8, _backgroundView.frame.size.height - 8);
    }
    else
    {
        if (_collectionView.contentSize.height > _collectionView.frame.size.height - _collectionView.contentInset.top - _collectionView.contentInset.bottom)
        {
            if (_collectionView.contentOffset.y < -_collectionView.contentInset.top)
            {
                CGFloat offset = -_collectionView.contentOffset.y - _collectionView.contentInset.top;
                _backgroundView.frame = CGRectMake(0, offset, self.frame.size.width, _backgroundView.frame.size.height);
                _maskView.frame = CGRectMake(_maskView.frame.origin.x, _maskView.frame.origin.y, _maskView.frame.size.width, _backgroundView.frame.size.height - 8 + MIN(8, offset));
                return;
            }
            else if (_collectionView.contentOffset.y + _collectionView.frame.size.height > _collectionView.contentSize.height + _collectionView.contentInset.bottom)
            {
                CGFloat offset = (_collectionView.contentSize.height - _collectionView.frame.size.height - _collectionView.contentOffset.y + _collectionView.contentInset.bottom);
                _backgroundView.frame = CGRectMake(0, offset + MAX(-8, offset * 2), self.frame.size.width, _backgroundView.frame.size.height);
                _maskView.frame = CGRectMake(_maskView.frame.origin.x, 4 - MIN(8, -offset * 2), _maskView.frame.size.width, _maskView.frame.size.height);
                return;
            }
            
            _backgroundView.frame = CGRectMake(0, 0, self.frame.size.width, _backgroundView.frame.size.height);
            _maskView.frame = CGRectMake(_backgroundView.frame.origin.x + 4, _backgroundView.frame.origin.y + 4, _backgroundView.frame.size.width - 8, _backgroundView.frame.size.height - 8);
        }
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (decelerate)
        _isAnimating = true;
    else
        [self scrollViewDidEndDecelerating:scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)__unused scrollView
{
    _isAnimating = false;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if ([view isDescendantOfView:_collectionView])
        return view;
    
    return nil;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [UIView performWithoutAnimation:^
    {
        [self _layoutCollectionViewForOrientation:self.interfaceOrientation];
        
        switch (self.interfaceOrientation)
        {
            case UIInterfaceOrientationLandscapeLeft:
            {
                _collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
                [_collectionViewLayout invalidateLayout];
                
                _arrowView.transform = CGAffineTransformMakeRotation((CGFloat)-M_PI_2);
                _arrowView.frame = CGRectMake(-MediaPickerSelectedPhotosViewArrowSize.height,
                                              18.5f,
                                              MediaPickerSelectedPhotosViewArrowSize.height,
                                              MediaPickerSelectedPhotosViewArrowSize.width);
            }
                break;
                
            case UIInterfaceOrientationLandscapeRight:
            {
                _collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
                [_collectionViewLayout invalidateLayout];
                
                _arrowView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_2);
                _arrowView.frame = CGRectMake(self.frame.size.width,
                                              18.5f,
                                              MediaPickerSelectedPhotosViewArrowSize.height,
                                              MediaPickerSelectedPhotosViewArrowSize.width);
            }
                break;
                
            default:
            {
                _collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
                [_collectionViewLayout invalidateLayout];
                
                _arrowView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
                _arrowView.frame = CGRectMake(self.frame.size.width - MediaPickerSelectedPhotosViewArrowSize.width - 18.5f,
                                              self.frame.size.height,
                                              MediaPickerSelectedPhotosViewArrowSize.width,
                                              MediaPickerSelectedPhotosViewArrowSize.height);
            }
                break;
        }
    }];
}

- (void)_layoutCollectionViewForOrientation:(UIInterfaceOrientation)orientation
{
    NSInteger numberOfItems = MAX(1, [self collectionView:_collectionView numberOfItemsInSection:0]);
    CGFloat size = 0.0f;

    if (UIInterfaceOrientationIsPortrait(orientation))
    {
        size = numberOfItems * (_collectionViewLayout.itemSize.width + _collectionViewLayout.minimumInteritemSpacing) - _collectionViewLayout.minimumInteritemSpacing;
        
        size = MAX(0, MIN(self.frame.size.width, size + 8));
        _backgroundView.frame = CGRectMake(self.frame.size.width - size, 0, size, self.frame.size.height);
    }
    else
    {
        size = numberOfItems * (_collectionViewLayout.itemSize.height + _collectionViewLayout.minimumInteritemSpacing) - _collectionViewLayout.minimumInteritemSpacing;
        
        size = MAX(0, MIN(self.frame.size.height, size + 8));
        _backgroundView.frame = CGRectMake(0, 0, self.frame.size.width, size);
    }
    
    CGRect maskViewFrame = CGRectMake(_backgroundView.frame.origin.x + 4, _backgroundView.frame.origin.y + 4, _backgroundView.frame.size.width - 8, _backgroundView.frame.size.height - 8);
    
    if (!CGRectEqualToRect(maskViewFrame, _maskView.frame))
    {
        _maskView.frame = maskViewFrame;
        _collectionView.frame = CGRectMake(-40, -40, _maskView.frame.size.width + 80, _maskView.frame.size.height + 80);
    }
    
    if (self.hidden)
        [self setHidden:self.hidden animated:false];
}

@end
