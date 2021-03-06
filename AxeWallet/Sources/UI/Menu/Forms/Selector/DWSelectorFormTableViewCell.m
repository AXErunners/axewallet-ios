//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Axe Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DWSelectorFormTableViewCell.h"

#import "DWSharedUIConstants.h"
#import "DWUIKit.h"

NS_ASSUME_NONNULL_BEGIN

static CGSize const ACCESSORY_SIZE = {26.0, 26.0};

static UIImage *_Nullable AccessoryImageForType(DWSelectorFormAccessoryType type) {
    switch (type) {
        case DWSelectorFormAccessoryType_None:
            return nil;
        case DWSelectorFormAccessoryType_DisclosureIndicator:
            return [UIImage imageNamed:@"icon_disclosure_indicator"];
        case DWSelectorFormAccessoryType_CheckmarkEmpty:
            return [UIImage imageNamed:@"icon_checkbox"];
        case DWSelectorFormAccessoryType_CheckmarkSelected:
            return [UIImage imageNamed:@"icon_checkbox_checked"];
    }
}

@interface DWSelectorFormTableViewCell ()

@property (readonly, nonatomic, strong) UILabel *titleLabel;
@property (readonly, nonatomic, strong) UILabel *detailLabel;
@property (readonly, nonatomic, strong) UIImageView *accessoryImageView;

@end

@implementation DWSelectorFormTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        UIView *contentView = self.roundedContentView;
        NSParameterAssert(contentView);

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.backgroundColor = [UIColor dw_backgroundColor];
        titleLabel.textColor = [UIColor dw_darkTitleColor];
        titleLabel.numberOfLines = 0;
        titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        titleLabel.font = [UIFont dw_fontForTextStyle:UIFontTextStyleCallout];
        titleLabel.adjustsFontForContentSizeCategory = YES;
        titleLabel.minimumScaleFactor = 0.5;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired - 2
                                                    forAxis:UILayoutConstraintAxisVertical];
        [contentView addSubview:titleLabel];
        _titleLabel = titleLabel;

        UILabel *detailLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        detailLabel.backgroundColor = [UIColor dw_backgroundColor];
        detailLabel.textAlignment = NSTextAlignmentRight;
        detailLabel.textColor = [UIColor dw_axeBlueColor];
        detailLabel.numberOfLines = 0;
        detailLabel.lineBreakMode = NSLineBreakByWordWrapping;
        detailLabel.font = [UIFont dw_fontForTextStyle:UIFontTextStyleSubheadline];
        detailLabel.adjustsFontForContentSizeCategory = YES;
        detailLabel.minimumScaleFactor = 0.5;
        detailLabel.adjustsFontSizeToFitWidth = YES;
        [detailLabel setContentCompressionResistancePriority:UILayoutPriorityRequired - 1
                                                     forAxis:UILayoutConstraintAxisHorizontal];
        [detailLabel setContentCompressionResistancePriority:UILayoutPriorityRequired - 1
                                                     forAxis:UILayoutConstraintAxisVertical];
        [detailLabel setContentHuggingPriority:UILayoutPriorityDefaultLow - 1
                                       forAxis:UILayoutConstraintAxisHorizontal];
        [contentView addSubview:detailLabel];
        _detailLabel = detailLabel;

        UIImageView *accessoryImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        accessoryImageView.translatesAutoresizingMaskIntoConstraints = NO;
        accessoryImageView.contentMode = UIViewContentModeCenter;
        [contentView addSubview:accessoryImageView];
        _accessoryImageView = accessoryImageView;

        const CGFloat margin = DWDefaultMargin();
        const CGFloat padding = DW_FORM_CELL_VERTICAL_PADDING;

        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor
                                                 constant:padding],
            [titleLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor
                                                     constant:margin],
            [titleLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor
                                                    constant:-padding],

            [detailLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor
                                                  constant:padding],
            [detailLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor
                                                      constant:DW_FORM_CELL_SPACING],
            [detailLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor
                                                     constant:-padding],

            [accessoryImageView.leadingAnchor constraintEqualToAnchor:detailLabel.trailingAnchor
                                                             constant:DW_FORM_CELL_SPACING],
            [accessoryImageView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor
                                                              constant:-margin],
            [accessoryImageView.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor],
            [accessoryImageView.widthAnchor constraintEqualToConstant:ACCESSORY_SIZE.width],
            [accessoryImageView.heightAnchor constraintEqualToConstant:ACCESSORY_SIZE.height],
        ]];

        [self setupObserving];
    }

    return self;
}

- (void)setupObserving {
    [self mvvm_observe:DW_KEYPATH(self, cellModel.title)
                  with:^(__typeof(self) self, NSString *value) {
                      self.titleLabel.text = value ?: @" ";
                  }];

    [self mvvm_observe:DW_KEYPATH(self, cellModel.subTitle)
                  with:^(__typeof(self) self, NSString *value) {
                      self.detailLabel.text = value ?: @" ";
                  }];

    [self mvvm_observe:DW_KEYPATH(self, cellModel.accessoryType)
                  with:^(typeof(self) self, NSNumber *value) {
                      const DWSelectorFormAccessoryType accessoryType = value.unsignedIntegerValue;
                      UIImage *image = AccessoryImageForType(accessoryType);
                      self.accessoryImageView.image = image;
                  }];

    [self mvvm_observe:DW_KEYPATH(self, cellModel.style)
                  with:^(__typeof(self) self, NSNumber *value) {
                      const DWSelectorFormCellModelStyle style = value.unsignedIntegerValue;
                      UIColor *color = nil;
                      switch (style) {
                          case DWSelectorFormCellModelStyleBlack:
                              color = [UIColor dw_darkTitleColor];
                              break;
                          case DWSelectorFormCellModelStyleBlue:
                              color = [UIColor dw_axeBlueColor];
                              break;
                          case DWSelectorFormCellModelStyleRed:
                              color = [UIColor dw_redColor];
                              break;
                      }
                      self.titleLabel.textColor = color;
                  }];

#if SNAPSHOT
    [self mvvm_observe:DW_KEYPATH(self, cellModel.accessibilityIdentifier)
                  with:^(typeof(self) self, NSString *value) {
                      self.accessibilityIdentifier = value;
                  }];
#endif /* SNAPSHOT */
}

@end

NS_ASSUME_NONNULL_END
