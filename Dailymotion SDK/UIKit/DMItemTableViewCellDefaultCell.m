//
//  DMItemTableViewCellDefaultCell.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 26/06/12.
//
//

#import "DMItemTableViewCellDefaultCell.h"

static UIImage *placeHolderImage;

@interface DMItemTableViewDefaultCell ()

@property (nonatomic, copy) NSURL *URL;

@end

@implementation DMItemTableViewDefaultCell

- (NSArray *)fieldsNeeded
{
    return @[@"thumbnail_small_url", @"title", @"owner.screenname"];
}

- (void)prepareForLoading
{
    self.textLabel.text = @"Loading…";
    self.detailTextLabel.text = @"";

    if (!placeHolderImage)
    {
        CGRect rect = CGRectMake(0, 0, 80, 60);
        UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
        [[UIColor lightGrayColor] setFill];
        UIRectFill(rect);
        placeHolderImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    self.imageView.image = placeHolderImage;
}

- (void)setFieldsData:(NSDictionary *)data
{
    // To be overwriten
    
    self.textLabel.text = data[@"title"];
    self.detailTextLabel.text = data[@"owner.screenname"];
    
    [self setNeedsLayout];

    __weak DMItemTableViewDefaultCell *wself = self;
    self.URL = data[@"thumbnail_small_url"];
    NSURL *localURL = [self.URL copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:localURL]];
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (!wself) return;
            __strong DMItemTableViewDefaultCell *sself = wself;

            // Only set downloaded image if still the current image for the cell.
            // Using cancellable operation for image downloading is highly recommended here.
            // See http://github.com/rs/SDWebImage for a library that handle this for you.
            if ([localURL isEqual:sself.URL])
            {
                sself.imageView.image = image;
                [sself setNeedsLayout];
            }
        });
    });
}

@end
