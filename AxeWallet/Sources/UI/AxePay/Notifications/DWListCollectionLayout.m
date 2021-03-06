//
//  Created by Andrew Podkovyrin
//  Copyright © 2020 Axe Core Group. All rights reserved.
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

#import "DWListCollectionLayout.h"

static UIEdgeInsets const INSETS = {0.0, 10.0, 0.0, 10.0};

@implementation DWListCollectionLayout

- (instancetype)init {
    self = [super init];
    if (self) {
        self.scrollDirection = UICollectionViewScrollDirectionVertical;
        self.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize;
        self.sectionInset = INSETS;
        self.sectionHeadersPinToVisibleBounds = YES;
    }
    return self;
}

- (CGFloat)contentWidth {
    return ceil(CGRectGetWidth(self.collectionView.safeAreaLayoutGuide.layoutFrame) - self.sectionInset.left - self.sectionInset.right);
}

@end
