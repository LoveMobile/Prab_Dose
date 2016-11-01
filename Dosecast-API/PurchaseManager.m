//
//  PurchaseManager.m
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "PurchaseManager.h"
#import "StoreKit/SKProduct.h"
#import "StoreKit/SKPayment.h"
#import "StoreKit/SKPaymentTransaction.h"
#import "StoreKit/SKError.h"
#import "DosecastUtil.h"
#import "HistoryManager.h"
#import "LocalNotificationManager.h"
#import "DataModel.h"
#import "GlobalSettings.h"
#import "NSData+Base64.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"
#import "PillNotificationManager.h"

static PurchaseManager *gInstance = nil;
static NSString* PremiumProductID = @"com.montunosoftware.pillpopper.premium";
static NSString* Subscription1MonthProductID = @"com.montunosoftware.pillpopper.subscription1month";
static NSString* Subscription1YearProductID = @"com.montunosoftware.pillpopper.subscription1year";

NSString *PurchaseManagerSubscriptionPurchased = @"PurchaseManagerSubscriptionPurchased";

@implementation PurchaseManager

@synthesize delegate;
@synthesize productList;

- (id)init
{
    if ((self = [super init]))
    {
		productList = [[NSMutableArray alloc] init];
		numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
		delegate = nil;
		startedProcessingTransactions = NO;
		restoredPastPurchase = NO;
        restoredPaymentTransactions = [[NSMutableArray alloc] init];
    }
	
    return self;
}

- (void)dealloc
{
    [self stopProcessingTransactions];
}

// Singleton methods

+ (PurchaseManager*) getInstance
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

// Called on startup to indicate that the app is ready to start processing pending transactions
- (void)startProcessingTransactions
{
	if (!startedProcessingTransactions)
	{
		DebugLog(@"start processing transactions start");

		[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
		startedProcessingTransactions = YES;
				
		DebugLog(@"start processing transactions end");
	}
}

// Called to stop processing pending transactions
- (void)stopProcessingTransactions
{
    DebugLog(@"stop processing transactions start");

    if (startedProcessingTransactions)
    {
		[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
        startedProcessingTransactions = NO;
    }
    
    DebugLog(@"stop processing transactions end");
}

// Find a particular product
- (SKProduct*)getProductWithID:(NSString*)productID
{
	SKProduct* product = nil;
	for (int i = 0; i < [productList count] && !product; i++)
	{
		SKProduct* p = (SKProduct*)[productList objectAtIndex:i];
		if ([p.productIdentifier caseInsensitiveCompare:productID] == NSOrderedSame)
			product = p;
	}
	return product;
}


// Returns the display price for the product with the given ID
- (NSString*)getDisplayPriceForProduct:(SKProduct*)p
{
	NSString* displayPrice = nil;
	if (p)
	{
		[numberFormatter setLocale:p.priceLocale];
		displayPrice = [numberFormatter stringFromNumber:p.price];
	}
	return displayPrice;	
}

// Call to refresh product list
- (void)refreshProductList
{
	DebugLog(@"refresh product list start");

    [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerRetrievingProductList", @"Dosecast", [DosecastUtil getResourceBundle], @"Retrieving product list", @"The message appearing in the spinner view when retrieving the product list"])];

	SKProductsRequest *request= [[SKProductsRequest alloc] initWithProductIdentifiers:
                                 [NSSet setWithObjects:Subscription1MonthProductID, Subscription1YearProductID, nil]];
	request.delegate = self;
	[request start];
	
	DebugLog(@"refresh product list end");
}

// Call to purchase the given product
- (void)purchaseProduct:(SKProduct*)p
{
	DebugLog(@"purchase product start");

    [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerProcessingPurchase", @"Dosecast", [DosecastUtil getResourceBundle], @"Processing purchase", @"The message appearing in the spinner view when processing a purchase"])];

	SKPayment *payment = [SKPayment paymentWithProduct:p];
	[[SKPaymentQueue defaultQueue] addPayment:payment];
	
	DebugLog(@"purchase product end");
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	DebugLog(@"productsRequest didReceiveResponse start");

	[productList removeAllObjects];
	[productList addObjectsFromArray:response.products];
		
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

    if (delegate && [delegate respondsToSelector:@selector(handleProductListRefreshed)])
	{
		[delegate handleProductListRefreshed];
	}
	DebugLog(@"productsRequest didReceiveResponse end");
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions
{
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
	DebugLog(@"paymentQueue restoreCompletedTransactionsFailedWithError start: %@", error);

    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

	NSString* messageText = NSLocalizedStringWithDefaultValue(@"ErrorPurchaseTransactionRestoreFailedMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not restore your past purchases due to the following error: %@", @"The message in the alert appearing if an error occurred when restoring a past purchase"]);
	DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorPurchaseTransactionRestoreFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Restore Past Purchases", @"The title on the alert appearing if an error occurred when restoring a past purchase"])
                                                                                       message:[NSString stringWithFormat:messageText, [DosecastUtil getProductAppName], [error localizedDescription]]];
    UINavigationController* mainNavigationController = [[PillNotificationManager getInstance].delegate getUINavigationController];
    UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
    
    [alert showInViewController:topNavController.topViewController];
	   
	DebugLog(@"paymentQueue restoreCompletedTransactionsFailedWithError end");
}

- (int) getNumMonthsToExtendSubscriptionForTransaction:(SKPaymentTransaction*)transaction
{
    if ([transaction.payment.productIdentifier isEqualToString:Subscription1MonthProductID])
        return 1;
    else if ([transaction.payment.productIdentifier isEqualToString:Subscription1YearProductID])
        return 12;
    else
        return 0;
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{	
    for (SKPaymentTransaction *transaction in transactions)
    {
		if (transaction.transactionState == SKPaymentTransactionStatePurchased)
		{
			DebugLog(@"paymentQueue updatedTransactions purchased start");

            DataModel* dataModel = [DataModel getInstance];

            [dataModel allowDosecastUserInteractionsWithMessage:NO];
            
            int numMonthsToExtend = [self getNumMonthsToExtendSubscriptionForTransaction:transaction];
            NSDate* newExpirationDate = nil;
            if (dataModel.globalSettings.subscriptionExpires && [dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] > 0)
                newExpirationDate = [DosecastUtil getLastSecondOnDate:[DosecastUtil addMonthsToDate:dataModel.globalSettings.subscriptionExpires numMonths:numMonthsToExtend]];
            else
                newExpirationDate = [DosecastUtil getLastSecondOnDate:[DosecastUtil addMonthsToDate:[NSDate date] numMonths:numMonthsToExtend]];

            [[LocalNotificationManager getInstance] subscribe:[transaction.transactionReceipt base64EncodedString]
                                            newExpirationDate:newExpirationDate
                                                    respondTo:nil
                                                        async:NO];
            
            [self finishTransaction:transaction];
            
            [[NSNotificationCenter defaultCenter] postNotification:
             [NSNotification notificationWithName:PurchaseManagerSubscriptionPurchased object:self]];
            
            // Report back to our delegate, if any
            if (delegate && [delegate respondsToSelector:@selector(handleSubscribeComplete)])
            {
                [delegate handleSubscribeComplete];
            }

			DebugLog(@"paymentQueue updatedTransactions purchased end");
		}
		else if (transaction.transactionState == SKPaymentTransactionStateFailed)
		{
			DebugLog(@"paymentQueue updatedTransactions failed start: transactionState %d", (int)transaction.transactionState);

            [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

			if (transaction.error.code != SKErrorPaymentCancelled)
			{
                NSString* messageText = NSLocalizedStringWithDefaultValue(@"ErrorPurchaseTransactionFailedMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not process your purchase due to the following error: %@", @"The message in the alert appearing if an error occurred when processing a purchase"]);
                
                DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorPurchaseTransactionFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Process Purchase", @"The title on the alert appearing if an error occurred when processing a purchase"]) message:[NSString stringWithFormat:messageText, [DosecastUtil getProductAppName], [transaction.error localizedDescription]] style:DosecastAlertControllerStyleAlert];
                [alert addAction:
                 [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                                style:DosecastAlertActionStyleCancel
                                              handler:^(DosecastAlertAction *action){
                                                  // Remove the transaction from the payment queue.
                                                  [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                                              }]];

                UINavigationController* mainNavigationController = [[PillNotificationManager getInstance].delegate getUINavigationController];
                UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
                
                [alert showInViewController:topNavController.topViewController];
			}
            else
            {
                // Remove the transaction from the payment queue.
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
            
			DebugLog(@"paymentQueue updatedTransactions failed end");
		}
		else if (transaction.transactionState == SKPaymentTransactionStateRestored)
		{
			DebugLog(@"paymentQueue updatedTransactions restored start");

			restoredPastPurchase = YES;
            
            [restoredPaymentTransactions addObject:transaction];
			         
			DebugLog(@"paymentQueue updatedTransactions restored end");
		}
    }
}

// Call to finish the given transaction
- (void)finishTransaction:(SKPaymentTransaction*)transaction
{
	DebugLog(@"finish transaction start");

	// Remove the transaction from the payment queue.
	[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
	
	DebugLog(@"finish transaction end");
}

- (void)restoreCompletedTransactionsFinished
{
    restoredPastPurchase = NO;
    BOOL performedSubscribe = NO;
    
    NSMutableArray* transactionsToRemove = [[NSMutableArray alloc] init];
    
    // See if we have a transaction for a premium purchase. If so, process it. Remove any unknown transactions.
    for (SKPaymentTransaction* transaction in restoredPaymentTransactions)
    {
        if ([transaction.originalTransaction.payment.productIdentifier isEqualToString:PremiumProductID])
        {
            [transactionsToRemove addObject:transaction];
            [[LocalNotificationManager getInstance] upgrade:[transaction.originalTransaction.transactionReceipt base64EncodedString]
                                                  respondTo:nil
                                                      async:NO];
            performedSubscribe = YES;
            
            [self finishTransaction:transaction];
        }
    }
    
    if ([transactionsToRemove count] > 0)
        [restoredPaymentTransactions removeObjectsInArray:transactionsToRemove];
    
    if (performedSubscribe)
    {
        // Report back to our delegate, if any
        if (delegate && [delegate respondsToSelector:@selector(handleSubscribeComplete)])
        {
            [delegate handleSubscribeComplete];
        }
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
	DebugLog(@"paymentQueueRestoreCompletedTransactionsFinished start");
    
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:NO];
    
	if (!restoredPastPurchase)
	{
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorPurchaseTransactionRestoreFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Restore Past Purchases", @"The title on the alert appearing if an error occurred when restoring a past purchase"])
                                                                                   message:NSLocalizedStringWithDefaultValue(@"ErrorPurchaseTransactionRestoreNotFoundMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"No past purchase for this App Store account was found.", @"The message in the alert appearing if no past purchase was found when restoring a past purchase"]) style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction *action){
                                          [self restoreCompletedTransactionsFinished];
                                      }]];
        
        UINavigationController* mainNavigationController = [[PillNotificationManager getInstance].delegate getUINavigationController];
        UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
        
        [alert showInViewController:topNavController.topViewController];
	}
    else
        [self restoreCompletedTransactionsFinished];
    
	DebugLog(@"paymentQueueRestoreCompletedTransactionsFinished end");
}

// Called to restore completed transactions
- (void)restoreCompletedTransactions
{
	DebugLog(@"restoreCompletedTransactions start");

    [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerRestoringPurchase", @"Dosecast", [DosecastUtil getResourceBundle], @"Restoring purchase", @"The message appearing in the spinner view when restoring a purchase"])];

	restoredPastPurchase = NO;
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
	
	DebugLog(@"restoreCompletedTransactions end");
}

@end
