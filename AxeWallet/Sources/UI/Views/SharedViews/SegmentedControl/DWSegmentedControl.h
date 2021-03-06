//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Axe Core Group. All rights reserved.
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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DWSegmentedControl : UIControl

@property (nullable, copy, nonatomic) NSArray<NSString *> *items;

@property (nonatomic, assign) NSInteger selectedSegmentIndex;
/**
 Allows to set selection position between the items.
 Use this propery within `scrollViewDidScroll:` to update selection state accordingly.
 Paging in `UIScrollView` must be enabled.
 */
@property (nonatomic, assign) CGFloat selectedSegmentIndexPercent;
/**
 If this property set to `YES` selection will be animated when user switches current selected segment.
 If `DWSegmentedControl` is bounded to the scrollView via `selectedSegmentIndexPercent` property set this to
 `NO`. Default is `YES`.
 */
@property (nonatomic, assign) BOOL shouldAnimateSelection;

- (void)setSelectedSegmentIndex:(NSInteger)selectedSegmentIndex animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
