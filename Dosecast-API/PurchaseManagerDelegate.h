//
//  PurchaseManagerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/21/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//
@class SKPaymentTransaction;

@protocol PurchaseManagerDelegate

@required

// Called whenever the product list has been refreshed
- (void)handleProductListRefreshed;

// Called when the user initiated a subscribe and it completed successfully
- (void)handleSubscribeComplete;

@end
