//
//  AddressBookContact.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/22/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AddressBook/ABRecord.h"
#import "AddressBookContactDelegate.h"
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

typedef enum {
    AddressBookContactTypePerson       = 0,
    AddressBookContactTypeOrganization = 1
} AddressBookContactType;

@interface AddressBookContact : NSObject<NSMutableCopying>
{
@private
    AddressBookContactType contactType;
    NSString* name;
    NSObject<AddressBookContactDelegate>* __weak delegate;
    NSString* addressBookContactName;
    NSString* addressBookContactId;
}

- (id)init:(NSString*)n contactType:(AddressBookContactType)type;

// Initialization using a dictionary (the designated initializer)
- (id)initWithDictionary:(NSMutableDictionary*)dict name:(NSString*)n contactType:(AddressBookContactType)type;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Returns whether the given record ID is a valid contact (the same type as this instance)
- (BOOL) isValidContact:(ABRecordID)recordID;

// Get the name to display
- (NSString*) getDisplayName;

- (NSString*)name;
- (AddressBookContactType)contactType;

@property (nonatomic, assign) ABRecordID recordID;
@property (nonatomic, weak) NSObject<AddressBookContactDelegate>* delegate;

@end
