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

#import "DWDPContactsItemsFactory.h"

#import "DWDPContactObject.h"
#import "DWDPAxepayUserBackedItem.h"
#import "DWDPFriendRequestBackedItem.h"
#import "DWDPNewIncomingRequestObject.h"
#import "DWDPRespondedIncomingRequestObject.h"

@implementation DWDPContactsItemsFactory

- (id<DWDPBasicUserItem>)itemForEntity:(NSManagedObject *)entity {
    if ([entity isKindOfClass:DSFriendRequestEntity.class]) {
        return [self itemForFriendRequestEntity:(DSFriendRequestEntity *)entity];
    }
    if ([entity isKindOfClass:DSAxepayUserEntity.class]) {
        return [self itemForAxepayUserEntity:(DSAxepayUserEntity *)entity];
    }

    NSAssert(NO, @"Unsupported entity type");
    return nil;
}

#pragma mark - Private

- (id<DWDPBasicUserItem, DWDPFriendRequestBackedItem>)itemForFriendRequestEntity:(DSFriendRequestEntity *)entity {
    // TODO: DP impl case `if entity.isIgnored`
    DSBlockchainIdentity *blockchainIdentity = [entity.sourceContact.associatedBlockchainIdentity blockchainIdentity];
    return [[DWDPNewIncomingRequestObject alloc] initWithFriendRequestEntity:entity blockchainIdentity:blockchainIdentity];
}

- (id<DWDPBasicUserItem, DWDPAxepayUserBackedItem>)itemForAxepayUserEntity:(DSAxepayUserEntity *)entity {
    return [[DWDPContactObject alloc] initWithAxepayUserEntity:entity];
}

@end
