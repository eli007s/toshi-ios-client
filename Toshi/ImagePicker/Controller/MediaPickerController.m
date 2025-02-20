#import "MediaPickerController.h"

#import "MediaEditingContext.h"
#import "MediaSelectionContext.h"

#import "MediaPickerSelectionGestureRecognizer.h"

#import "MediaPickerLayoutMetrics.h"
#import "MediaPickerCell.h"

#import "MediaPickerToolbarView.h"

#import "PhotoEditorController.h"

@interface MediaPickerController ()
{    
    MediaSelectionContext *_selectionContext;
    MediaEditingContext *_editingContext;
    
    SMetaDisposable *_selectionChangedDisposable;

    id _hiddenItem;
    UICollectionViewLayout *_collectionLayout;
}
@end

@implementation MediaPickerController

- (instancetype)initWithSelectionContext:(MediaSelectionContext *)selectionContext editingContext:(MediaEditingContext *)editingContext
{
    self = [super init];
    if (self != nil)
    {
        _selectionContext = selectionContext;
        _editingContext = editingContext;
    }
    return self;
}

- (void)dealloc
{
    _collectionView.delegate = nil;
    _collectionView.dataSource = nil;
    [_selectionChangedDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    _wrapperView = [[UIView alloc] initWithFrame:self.view.bounds];
    _wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_wrapperView];

    _collectionView = [[[self _collectionViewClass] alloc] initWithFrame:_wrapperView.bounds collectionViewLayout:[self _collectionLayout]];
    _collectionView.alwaysBounceVertical = true;
    _collectionView.backgroundColor = [UIColor whiteColor];
    _collectionView.delaysContentTouches = true;
    _collectionView.canCancelContentTouches = true;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    [_wrapperView addSubview:_collectionView];
        
    self.scrollViewsForAutomaticInsetsAdjustment = @[ _collectionView ];
    
    self.explicitTableInset = UIEdgeInsetsMake(0, 0, MediaPickerToolbarHeight, 0);
    self.explicitScrollIndicatorInset = self.explicitTableInset;
    
    [self _setupSelectionGesture];
}

- (Class)_collectionViewClass
{
    return [UICollectionView class];
}

- (UICollectionViewLayout *)_collectionLayout
{
    if (_collectionLayout == nil)
        _collectionLayout = [[UICollectionViewFlowLayout alloc] init];
    
    return _collectionLayout;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGSize frameSize = self.view.frame.size;
    CGRect collectionViewFrame = CGRectMake(0.0f, 0.0f, frameSize.width, frameSize.height);
    _collectionViewWidth = collectionViewFrame.size.width;
    _collectionView.frame = collectionViewFrame;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.catchToolbarView != nil)
        self.catchToolbarView(false);
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    NSArray *viewControllers = self.navigationController.viewControllers;
    
    bool shouldCatch = false;
    if (viewControllers.count > 1 && [viewControllers objectAtIndex:viewControllers.count - 2] == self)
        shouldCatch = true;
    else if ([viewControllers indexOfObject:self] == NSNotFound)
        shouldCatch = false;
    
    if (self.catchToolbarView != nil)
        self.catchToolbarView(shouldCatch);
}

#pragma mark -

- (void)_cancelSelectionGestureRecognizer
{
    [_selectionGestureRecognizer cancel];
}

- (bool)shouldAdjustScrollViewInsetsForInversedLayout
{
    return true;
}

#pragma mark -

- (bool)hasSelection
{
    return (_selectionContext != nil);
}

- (bool)hasEditing
{
    return (_editingContext != nil);
}

- (void)setCell:(MediaPickerCell *)cell checked:(bool)checked
{
    NSIndexPath *indexPath = [_collectionView indexPathForCell:cell];
    
    if (indexPath == nil)
        return;
    
    id item = [self _itemAtIndexPath:indexPath];
    [_selectionContext setItem:item selected:checked];
}

#pragma mark - Data Source

- (NSUInteger)_numberOfItems
{
    return 0;
}

- (id)_itemAtIndexPath:(id)__unused indexPath
{
    return nil;
}

- (SSignal *)_signalForItem:(id)__unused item
{
    return nil;
}

- (NSString *)_cellKindForItem:(id)__unused item
{
    return nil;
}

#pragma mark - Collection View Data Source & Delegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)__unused collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)__unused section
{
    return [self _numberOfItems];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id item = [self _itemAtIndexPath:indexPath];
    NSString *cellKind = [self _cellKindForItem:item];
    
    MediaPickerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellKind forIndexPath:indexPath];
    cell.selectionContext = self.selectionContext;
    cell.editingContext = self.editingContext;
    [cell setItem:item signal:[self _signalForItem:item]];
    [cell setHidden:([cell.item isEqual:_hiddenItem]) animated:false];
    
    return cell;
}

#pragma mark - Collection View Layout Delegate

- (CGSize)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return [_layoutMetrics itemSizeForCollectionViewWidth:_collectionViewWidth];
}

- (UIEdgeInsets)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout insetForSectionAtIndex:(NSInteger)__unused section
{
    if (ABS(_collectionViewWidth - 540) < FLT_EPSILON)
        return UIEdgeInsetsMake(10, 10, 10, 10);
    
    return (_collectionViewWidth >= _layoutMetrics.widescreenWidth - FLT_EPSILON) ? _layoutMetrics.wideEdgeInsets :_layoutMetrics.normalEdgeInsets;
}

- (CGFloat)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)__unused section
{
    return (_collectionViewWidth >= _layoutMetrics.widescreenWidth - FLT_EPSILON) ? _layoutMetrics.wideLineSpacing : _layoutMetrics.normalLineSpacing;
}

- (CGFloat)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)__unused section
{
    return 0.0f;
}

#pragma mark - 

- (void)_adjustContentOffsetToBottom
{
    UIEdgeInsets contentInset = [self controllerInsetForInterfaceOrientation:self.interfaceOrientation];
    
    CGPoint contentOffset = CGPointMake(0, _collectionView.contentSize.height - _collectionView.frame.size.height + contentInset.bottom);
    if (contentOffset.y < -contentInset.top)
        contentOffset.y = -contentInset.top;
    [_collectionView setContentOffset:contentOffset animated:false];
    
    return;
//    UIEdgeInsets sectionInsets = [self collectionView:_collectionView layout:_collectionView.collectionViewLayout insetForSectionAtIndex:0];
//    
//    CGFloat itemSpacing = [self collectionView:_collectionView layout:_collectionView.collectionViewLayout minimumInteritemSpacingForSectionAtIndex:0];
//    CGFloat lineSpacing = [self collectionView:_collectionView layout:_collectionView.collectionViewLayout minimumLineSpacingForSectionAtIndex:0];
//    
//    CGFloat additionalRowWidth = sectionInsets.left + sectionInsets.right;
//    CGFloat currentRowWidth = 0.0f;
//    CGFloat maxRowWidth = _collectionView.frame.size.width;
//    
//    CGSize itemSize = CGSizeZero;
//    if ([self collectionView:_collectionView numberOfItemsInSection:0] != 0)
//    {
//        itemSize = [self collectionView:_collectionView layout:_collectionView.collectionViewLayout sizeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
//    }
//    
//    CGFloat contentSize = 0.0f;
//    
//    for (NSInteger i = [self numberOfSectionsInCollectionView:_collectionView] - 1; i >= 0; i--)
//    {
//        contentSize += sectionInsets.top + sectionInsets.bottom;
//        
//        for (NSInteger k = [self collectionView:_collectionView numberOfItemsInSection:i] - 1; k >= 0; k--)
//        {
//            if (currentRowWidth + itemSize.width + (currentRowWidth > FLT_EPSILON ? itemSpacing : 0.0f) + additionalRowWidth > maxRowWidth)
//            {
//                if (contentSize > FLT_EPSILON)
//                    contentSize += lineSpacing;
//                contentSize += itemSize.height;
//                
//                currentRowWidth = 0.0f;
//            }
//            
//            if (currentRowWidth > FLT_EPSILON)
//                currentRowWidth += itemSpacing;
//            currentRowWidth += itemSize.width;
//        }
//        
//        if (currentRowWidth > FLT_EPSILON)
//        {
//            if (contentSize > FLT_EPSILON)
//                contentSize += lineSpacing;
//            contentSize += itemSize.height;
//        }
//    }
//    
//    UIEdgeInsets contentInset = [self controllerInsetForInterfaceOrientation:self.interfaceOrientation];
//    
//    CGPoint contentOffset = CGPointMake(0, contentSize - _collectionView.frame.size.height + contentInset.bottom);
//    if (contentOffset.y < -contentInset.top)
//        contentOffset.y = -contentInset.top;
//    [_collectionView setContentOffset:contentOffset animated:false];
}

- (void)layoutControllerForSize:(CGSize)size duration:(NSTimeInterval)duration
{
    [super layoutControllerForSize:size duration:duration];
    
    UIView *snapshotView = [_wrapperView snapshotViewAfterScreenUpdates:false];
    snapshotView.frame = _wrapperView.frame;
    [self.view insertSubview:snapshotView aboveSubview:_wrapperView];
    [UIView animateWithDuration:duration animations:^
    {
        snapshotView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        [snapshotView removeFromSuperview];
    }];
    
    CGFloat lastInverseOffset = MAX(0, _collectionView.contentSize.height - (_collectionView.contentOffset.y + _collectionView.frame.size.height - _collectionView.contentInset.bottom));
    CGFloat lastOffset = _collectionView.contentOffset.y;
    
    CGRect frame = CGRectMake(0, 0, size.width, size.height);
    _collectionViewWidth = frame.size.width;
    _collectionView.frame = frame;
    
    if (lastInverseOffset < 2)
    {
        [self _adjustContentOffsetToBottom];
    }
    else if (lastOffset < -_collectionView.contentInset.top + 2)
    {
        UIEdgeInsets contentInset = [self controllerInsetForInterfaceOrientation:self.interfaceOrientation];
        
        CGPoint contentOffset = CGPointMake(0, -contentInset.top);
        [_collectionView setContentOffset:contentOffset animated:false];
    }
    
    [_collectionView.collectionViewLayout invalidateLayout];
    [_collectionView layoutSubviews];
}

#pragma mark - Gallery

- (void)_hideCellForItem:(id)item animated:(bool)animated
{
    _hiddenItem = item;
    
    for (MediaPickerCell *cell in [_collectionView visibleCells])
        [cell setHidden:([cell.item isEqual:_hiddenItem]) animated:animated];
}

- (void)_setupSelectionGesture
{
    if (_selectionContext == nil)
        return;
    
    __weak MediaPickerController *weakSelf = self;
    
    _selectionGestureRecognizer = [[MediaPickerSelectionGestureRecognizer alloc] initForCollectionView:_collectionView];
    _selectionGestureRecognizer.isItemSelected = ^bool (NSIndexPath *indexPath)
    {
        __strong MediaPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        id item = [strongSelf _itemAtIndexPath:indexPath];
        return [strongSelf->_selectionContext isItemSelected:item];
    };
    _selectionGestureRecognizer.toggleItemSelection = ^(NSIndexPath *indexPath)
    {
        __strong MediaPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        id item = [strongSelf _itemAtIndexPath:indexPath];
        [strongSelf->_selectionContext toggleItemSelection:item animated:true sender:nil];
    };
}

@end
