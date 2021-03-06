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

#import "DWDPEstablishedContactObject.h"
#import "DWDPNotificationItem.h"

NS_ASSUME_NONNULL_BEGIN

@class DSFriendRequestEntity;

// TODO: DP consider removing this notification type

@interface DWDPEstablishedContactNotificationObject : DWDPEstablishedContactObject <DWDPNotificationItem>

- (instancetype)initWithFriendRequestEntity:(DSFriendRequestEntity *)friendRequestEntity
                         blockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity;

- (instancetype)initWithBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
