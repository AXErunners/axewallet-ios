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

#import "DWBaseContactsContentViewController+DWProtected.h"

#import "DWDPBasicCell.h"
#import "DWListCollectionLayout.h"
#import "DWSharedUIConstants.h"
#import "DWUIKit.h"
#import "DWUserProfileViewController.h"
#import "UICollectionView+DWDPItemDequeue.h"

typedef NS_ENUM(NSInteger, DWContactsContentSection) {
    DWContactsContentSectionSearch,
    DWContactsContentSectionRequests,
    DWContactsContentSectionContacts,
    CountOfDWContactsContentSections,
};

@implementation DWBaseContactsContentViewController

- (instancetype)initWithPayModel:(id<DWPayModelProtocol>)payModel
                    dataProvider:(id<DWTransactionListDataProviderProtocol>)dataProvider {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _payModel = payModel;
        _dataProvider = dataProvider;
    }
    return self;
}

- (NSUInteger)maxVisibleContactRequestsCount {
    return NSUIntegerMax;
}

- (void)setDataSource:(id<DWContactsDataSource>)dataSource {
    _dataSource = dataSource;

    self.searchHeaderTitle = nil;
    self.requestsHeaderTitle = nil;
    self.contactsHeaderFilterButtonTitle = nil;

    // TODO: DP polishing: diff reload
    [self.collectionView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor dw_secondaryBackgroundColor];

    [self.view addSubview:self.collectionView];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return CountOfDWContactsContentSections;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (section == DWContactsContentSectionSearch) {
        return 0;
    }
    else if (section == DWContactsContentSectionRequests) {
        return MIN(self.dataSource.requestsCount, self.maxVisibleContactRequestsCount);
    }
    else {
        return self.dataSource.contactsCount;
    }
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    DWListCollectionLayout *layout = (DWListCollectionLayout *)collectionView.collectionViewLayout;
    NSAssert([layout isKindOfClass:DWListCollectionLayout.class], @"Invalid layout");
    const CGFloat contentWidth = layout.contentWidth;

    id<DWDPBasicUserItem> item = [self itemAtIndexPath:indexPath];
    DWDPBasicCell *cell = [collectionView dw_dequeueReusableCellForItem:item atIndexPath:indexPath];
    cell.contentWidth = contentWidth;
    cell.displayItemBackgroundView = indexPath.section == DWContactsContentSectionRequests;
    cell.delegate = self.itemsDelegate;
    [cell setItem:item highlightedText:self.dataSource.trimmedQuery];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    const NSInteger section = indexPath.section;
    if ([self shouldDisplayHeaderForSection:section] == NO) {
        return [[UICollectionReusableView alloc] init];
    }

    if (section == DWContactsContentSectionSearch) {
        DWContactsSearchInfoHeaderView *headerView = (DWContactsSearchInfoHeaderView *)[collectionView
            dequeueReusableSupplementaryViewOfKind:kind
                               withReuseIdentifier:DWContactsSearchInfoHeaderView.dw_reuseIdentifier
                                      forIndexPath:indexPath];
        headerView.titleLabel.attributedText = self.searchHeaderTitle;
        return headerView;
    }
    else if (section == DWContactsContentSectionRequests) {
        const BOOL shouldHideViewAll = [self shouldHideViewAllRequests];
        DWTitleActionHeaderView *headerView = (DWTitleActionHeaderView *)[collectionView
            dequeueReusableSupplementaryViewOfKind:kind
                               withReuseIdentifier:DWTitleActionHeaderView.dw_reuseIdentifier
                                      forIndexPath:indexPath];
        headerView.titleLabel.text = self.requestsHeaderTitle;
        headerView.delegate = self;
        headerView.actionButton.hidden = shouldHideViewAll;
        [headerView.actionButton setTitle:NSLocalizedString(@"View All", nil) forState:UIControlStateNormal];
        return headerView;
    }
    else {
        DWFilterHeaderView *headerView = (DWFilterHeaderView *)[collectionView
            dequeueReusableSupplementaryViewOfKind:kind
                               withReuseIdentifier:DWFilterHeaderView.dw_reuseIdentifier
                                      forIndexPath:indexPath];
        headerView.titleLabel.text = NSLocalizedString(@"My Contacts", nil);
        headerView.delegate = self;
        [headerView.filterButton setAttributedTitle:self.contactsHeaderFilterButtonTitle forState:UIControlStateNormal];
        return headerView;
    }
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];

    id<DWDPBasicUserItem> item = [self itemAtIndexPath:indexPath];

    DWUserProfileViewController *controller =
        [[DWUserProfileViewController alloc] initWithItem:item
                                                 payModel:self.payModel
                                             dataProvider:self.dataProvider
                                       shouldSkipUpdating:YES];
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    if ([self shouldDisplayHeaderForSection:section] == NO) {
        return CGSizeZero;
    }

    DWListCollectionLayout *layout = (DWListCollectionLayout *)collectionView.collectionViewLayout;
    NSAssert([layout isKindOfClass:DWListCollectionLayout.class], @"Invalid layout");
    const CGFloat contentWidth = layout.contentWidth;

    UIView *measuringView = nil;
    if (section == DWContactsContentSectionSearch) {
        measuringView = self.measuringSearchHeaderView;
    }
    else if (section == DWContactsContentSectionRequests) {
        measuringView = self.measuringRequestsHeaderView;
    }
    else {
        measuringView = self.measuringContactsHeaderView;
    }
    measuringView.frame = CGRectMake(0, 0, contentWidth, 300);
    CGSize size = [measuringView systemLayoutSizeFittingSize:CGSizeMake(contentWidth, UILayoutFittingExpandedSize.height)
                               withHorizontalFittingPriority:UILayoutPriorityRequired
                                     verticalFittingPriority:UILayoutPriorityFittingSizeLevel];

    return size;
}

#pragma mark - DWFilterHeaderViewDelegate

- (void)filterHeaderView:(DWFilterHeaderView *)view filterButtonAction:(UIView *)sender {
    // to be overriden
}

#pragma mark - DWTitleActionHeaderViewDelegate

- (void)titleActionHeaderView:(DWTitleActionHeaderView *)view buttonAction:(UIView *)sender {
    // to be overriden
}

#pragma mark - Private

- (id<DWDPBasicUserItem>)itemAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.section > 0, @"Section 0 is empty and should not have any data items");
    NSIndexPath *dataIndexPath = [NSIndexPath indexPathForItem:indexPath.item inSection:indexPath.section - 1];
    id<DWDPBasicUserItem> item = [self.dataSource itemAtIndexPath:dataIndexPath];
    return item;
}

- (BOOL)shouldDisplayHeaderForSection:(NSInteger)section {
    if (section == DWContactsContentSectionSearch && self.dataSource.isSearching == NO) {
        return NO;
    }
    else if (section == DWContactsContentSectionRequests && self.dataSource.requestsCount == 0) {
        return NO;
    }
    else if (section == DWContactsContentSectionContacts && self.dataSource.contactsCount == 0) {
        return NO;
    }
    return YES;
}

- (UICollectionView *)collectionView {
    if (_collectionView == nil) {
        DWListCollectionLayout *layout = [[DWListCollectionLayout alloc] init];

        UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:UIScreen.mainScreen.bounds
                                                              collectionViewLayout:layout];
        collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        collectionView.backgroundColor = [UIColor dw_secondaryBackgroundColor];
        collectionView.dataSource = self;
        collectionView.delegate = self;
        collectionView.alwaysBounceVertical = YES;
        [collectionView dw_registerDPItemCells];
        [collectionView registerClass:DWContactsSearchInfoHeaderView.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:DWContactsSearchInfoHeaderView.dw_reuseIdentifier];
        [collectionView registerClass:DWTitleActionHeaderView.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:DWTitleActionHeaderView.dw_reuseIdentifier];
        [collectionView registerClass:DWFilterHeaderView.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:DWFilterHeaderView.dw_reuseIdentifier];

        _collectionView = collectionView;
    }
    return _collectionView;
}

- (DWContactsSearchInfoHeaderView *)measuringSearchHeaderView {
    if (_measuringSearchHeaderView == nil) {
        _measuringSearchHeaderView = [[DWContactsSearchInfoHeaderView alloc] initWithFrame:CGRectZero];
    }
    _measuringSearchHeaderView.titleLabel.attributedText = self.searchHeaderTitle;
    return _measuringSearchHeaderView;
}

- (DWTitleActionHeaderView *)measuringRequestsHeaderView {
    if (_measuringRequestsHeaderView == nil) {
        DWTitleActionHeaderView *view = [[DWTitleActionHeaderView alloc] initWithFrame:CGRectZero];
        [view.actionButton setTitle:NSLocalizedString(@"View All", nil) forState:UIControlStateNormal];
        _measuringRequestsHeaderView = view;
    }
    _measuringRequestsHeaderView.titleLabel.text = self.requestsHeaderTitle;
    _measuringRequestsHeaderView.actionButton.hidden = [self shouldHideViewAllRequests];
    return _measuringRequestsHeaderView;
}

- (DWFilterHeaderView *)measuringContactsHeaderView {
    if (_measuringContactsHeaderView == nil) {
        DWFilterHeaderView *headerView = [[DWFilterHeaderView alloc] initWithFrame:CGRectZero];
        headerView.titleLabel.text = NSLocalizedString(@"My Contacts", nil);
        _measuringContactsHeaderView = headerView;
    }
    [_measuringContactsHeaderView.filterButton setAttributedTitle:self.contactsHeaderFilterButtonTitle
                                                         forState:UIControlStateNormal];
    return _measuringContactsHeaderView;
}

- (BOOL)shouldHideViewAllRequests {
    id<DWContactsDataSource> dataSource = self.dataSource;
    const NSUInteger contactRequestsCount = dataSource.requestsCount;
    const BOOL isSearching = dataSource.isSearching;
    const BOOL hasMore = contactRequestsCount > self.maxVisibleContactRequestsCount;
    return isSearching || !hasMore;
}

- (NSAttributedString *)searchHeaderTitle {
    if (_searchHeaderTitle == nil) {
        NSString *query = self.dataSource.trimmedQuery;
        NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
        [result beginEditing];
        NSDictionary<NSAttributedStringKey, id> *plainAttributes = @{
            NSFontAttributeName : [UIFont dw_fontForTextStyle:UIFontTextStyleFootnote],
        };
        NSAttributedString *prefix =
            [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Search results for \"", @"Search results for \"John Doe\"")
                                            attributes:plainAttributes];
        [result appendAttributedString:prefix];
        NSAttributedString *queryString =
            [[NSAttributedString alloc] initWithString:query
                                            attributes:@{
                                                NSFontAttributeName : [UIFont dw_fontForTextStyle:UIFontTextStyleSubheadline],
                                            }];
        [result appendAttributedString:queryString];
        NSAttributedString *suffix = [[NSAttributedString alloc] initWithString:@"\"" attributes:plainAttributes];
        [result appendAttributedString:suffix];
        [result endEditing];
        _searchHeaderTitle = [result copy];
    }
    return _searchHeaderTitle;
}

- (NSString *)requestsHeaderTitle {
    if (_requestsHeaderTitle == nil) {
        const BOOL shouldHideViewAll = [self shouldHideViewAllRequests];
        if (shouldHideViewAll) {
            _requestsHeaderTitle = NSLocalizedString(@"Contact Requests", nil);
        }
        else {
            id<DWContactsDataSource> dataSource = self.dataSource;
            const NSUInteger contactRequestsCount = dataSource.requestsCount;
            _requestsHeaderTitle = [NSString stringWithFormat:@"%@ (%ld)",
                                                              NSLocalizedString(@"Contact Requests", nil),
                                                              contactRequestsCount];
        }
    }
    return _requestsHeaderTitle;
}

- (NSAttributedString *)contactsHeaderFilterButtonTitle {
    if (_contactsHeaderFilterButtonTitle == nil) {
        NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
        [result beginEditing];
        NSAttributedString *prefix =
            [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Sort by", nil)
                                            attributes:@{
                                                NSForegroundColorAttributeName : [UIColor dw_tertiaryTextColor],
                                                NSFontAttributeName : [UIFont dw_fontForTextStyle:UIFontTextStyleCaption1],
                                            }];
        [result appendAttributedString:prefix];

        [result appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        NSString *optionValue = nil;
        switch (self.dataSource.sortMode) {
            case DWContactsSortMode_ByUsername: {
                optionValue = NSLocalizedString(@"Name", nil);
                break;
            }
        }
        NSAttributedString *option =
            [[NSAttributedString alloc] initWithString:optionValue
                                            attributes:@{
                                                NSForegroundColorAttributeName : [UIColor dw_axeBlueColor],
                                                NSFontAttributeName : [UIFont dw_fontForTextStyle:UIFontTextStyleFootnote],
                                            }];
        [result appendAttributedString:option];
        [result endEditing];
        _contactsHeaderFilterButtonTitle = [result copy];
    }
    return _contactsHeaderFilterButtonTitle;
}

@end
