#import "MenuSheetTitleItemView.h"
#import "Font.h"
#import "Common.h"

@interface MenuSheetTitleItemView ()
{
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
}
@end

@implementation MenuSheetTitleItemView

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    self = [super initWithType:MenuSheetItemTypeDefault];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor whiteColor];
        _titleLabel.font = TGMediumSystemFontOfSize(13);
        _titleLabel.text = title;
        _titleLabel.textColor = UIColorRGB(0x8f8f8f);
        [self addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor whiteColor];
        _subtitleLabel.font = TGSystemFontOfSize(13);
        _subtitleLabel.text = subtitle;
        _subtitleLabel.textColor = UIColorRGB(0x8f8f8f);
        [self addSubview:_subtitleLabel];
    }
    return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width screenHeight:(CGFloat)__unused screenHeight
{
    CGFloat height = 17.0f;
    
    if (_titleLabel.text.length > 0)
    {
        NSAttributedString *string = [[NSAttributedString alloc] initWithString:_titleLabel.text attributes:@{ NSFontAttributeName: _titleLabel.font }];
        CGSize textSize = [string boundingRectWithSize:CGSizeMake(width - 18.0f * 2.0f, screenHeight) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size;
        _titleLabel.frame = CGRectMake(_titleLabel.frame.origin.x, _titleLabel.frame.origin.y, ceil(textSize.width), ceil(textSize.height));
        height += _titleLabel.frame.size.height;
    }

    if (_subtitleLabel.text.length > 0)
    {
        NSAttributedString *string = [[NSAttributedString alloc] initWithString:_subtitleLabel.text attributes:@{ NSFontAttributeName: _subtitleLabel.font }];
        CGSize textSize = [string boundingRectWithSize:CGSizeMake(width - 18.0f * 2.0f, screenHeight) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size;
        _subtitleLabel.frame = CGRectMake(_subtitleLabel.frame.origin.x, _subtitleLabel.frame.origin.y, ceil(textSize.width), ceil(textSize.height));
        height += _subtitleLabel.frame.size.height;
    }
    
    height += 15.0f;
    
    return height;
}

- (bool)requiresDivider
{
    return true;
}

- (void)layoutSubviews
{
    CGFloat topOffset = 17.0f;
    
    if (_titleLabel.text.length > 0)
    {
        _titleLabel.frame = CGRectMake(floor((self.frame.size.width - _titleLabel.frame.size.width) / 2.0f), topOffset, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
        topOffset += _titleLabel.frame.size.height;
    }
    
    if (_subtitleLabel.text.length > 0)
    {
        _subtitleLabel.frame = CGRectMake(floor((self.frame.size.width - _subtitleLabel.frame.size.width) / 2.0f), topOffset, _subtitleLabel.frame.size.width, _subtitleLabel.frame.size.height);
        topOffset += _subtitleLabel.frame.size.height;
    }
}

@end
