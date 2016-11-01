//
//  ContactsHelper.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 8/12/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "ContactsHelper.h"

NSString *ContactsHelperAddressBookAccessGranted = @"ContactsHelperAddressBookAccessGranted";

@implementation ContactsHelper

@synthesize accessGranted;
@synthesize addressBook;

- (id)init
{
    if ((self = [super init]))
    {
        accessGranted = NO;
        addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    }
    
    return self;
}

- (void)dealloc
{
    if(addressBook)
    {
        CFRelease(addressBook);
    }
}

// Check the authorization status of our application for Address Book
-(void)checkAddressBookAccess
{
    switch (ABAddressBookGetAuthorizationStatus())
    {
            // Update our UI if the user has granted access to their Contacts
        case  kABAuthorizationStatusAuthorized:
            [self accessGrantedForAddressBook];
            break;
            // Prompt the user for access to Contacts if there is no definitive answer
        case  kABAuthorizationStatusNotDetermined :
            [self requestAddressBookAccess];
            break;
            // Display a message if the user has denied or restricted access to Contacts
        case  kABAuthorizationStatusDenied:
        case  kABAuthorizationStatusRestricted:
        {
            // display alert to ask user to allow access
        }
            break;
        default:
            break;
    }
}

// Prompt the user for access to their Address Book data
-(void)requestAddressBookAccess
{
    ContactsHelper * __weak weakSelf = self;
    
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error)
    {
         if (granted)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [weakSelf accessGrantedForAddressBook];
                 
             });
         }
    });
}

// This method is called when the user has granted access to their address book data.
-(void)accessGrantedForAddressBook
{
    accessGranted = YES;
    
    [[NSNotificationCenter defaultCenter] postNotification:
     [NSNotification notificationWithName:ContactsHelperAddressBookAccessGranted object:nil]];
}

@end
