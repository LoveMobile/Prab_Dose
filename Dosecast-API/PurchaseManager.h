//
//  PurchaseManager.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PurchaseManagerDelegate.h"
#import "StoreKit/SKProductsRequest.h"
#import "StoreKit/SKPaymentQueue.h"

// Called to notify that a subscription was purchased
extern NSString *PurchaseManagerSubscriptionPurchased;

@class SKProduct;
@class SKPaymentTransaction;

@interface PurchaseManager : NSObject<SKProductsRequestDelegate,
                                      SKPaymentTransactionObserver>
{
@private
	NSMutableArray* productList;
	NSNumberFormatter* numberFormatter;
	NSObject<PurchaseManagerDelegate>* __weak delegate;
	BOOL startedProcessingTransactions;
	BOOL restoredPastPurchase;
	NSMutableArray* restoredPaymentTransactions;
}

// Singleton methods
+ (PurchaseManager*) getInstance;

// Find a particular product
- (SKProduct*)getProductWithID:(NSString*)productID;

// Returns the display price for the given product
- (NSString*)getDisplayPriceForProduct:(SKProduct*)p;

// Call to purchase the given product
- (void)purchaseProduct:(SKProduct*)p;

// Call to finish the given transaction
- (void)finishTransaction:(SKPaymentTransaction*)transaction;

// Call to refresh product list
- (void)refreshProductList;

// Called to start processing pending transactions
- (void)startProcessingTransactions;

// Called to stop processing pending transactions
- (void)stopProcessingTransactions;

// Called to restore completed transactions
- (void)restoreCompletedTransactions;

@property (nonatomic, readonly) NSArray* productList;
@property (nonatomic, weak) NSObject<PurchaseManagerDelegate>* delegate;

@end
