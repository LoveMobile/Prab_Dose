//
//  ContactsHelper.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 8/12/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

// This notification is fired when address book access is granted
extern NSString *ContactsHelperAddressBookAccessGranted;

@interface ContactsHelper : NSObject
{
@private
    ABAddressBookRef addressBook;
    BOOL accessGranted;
}

- (void) checkAddressBookAccess;

@property (nonatomic, readonly) BOOL accessGranted;
@property (nonatomic, readonly) ABAddressBookRef addressBook;

@end
