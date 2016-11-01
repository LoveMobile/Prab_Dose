//
//  AddressBookContact.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/22/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "AddressBookContact.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "ContactsHelper.h"
#import "Preferences.h"

@implementation AddressBookContact
@synthesize delegate;

- (id)init
{
    return [self init:nil contactType:AddressBookContactTypePerson];
}

- (id)initInternal:(NSString*)contactName
         contactId:(NSString*)contactId
              name:(NSString*)n
       contactType:(AddressBookContactType)type
{
    if ((self = [super init]))
    {
        if (!contactName)
            contactName = @"";
        if (!contactId)
            contactId = @"";
        addressBookContactName = contactName;
        addressBookContactId = contactId;
        contactType = type;
        name = n;
        delegate = nil;
    }
    
    return self;
}

- (id)init:(NSString*)n contactType:(AddressBookContactType)type
{
    return [self initInternal:nil contactId:nil name:n contactType:type];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[AddressBookContact alloc] initInternal:[addressBookContactName mutableCopyWithZone:zone]
                                          contactId:[addressBookContactId mutableCopyWithZone:zone]
                                               name:[name mutableCopyWithZone:zone]
                                        contactType:contactType];
}

// Initialization using a dictionary (the designated initializer)
- (id)initWithDictionary:(NSMutableDictionary*)dict name:(NSString*)n contactType:(AddressBookContactType)type
{
    NSString* nameKey = [NSString stringWithFormat:@"%@Name", n];
    NSString* idKey = [NSString stringWithFormat:@"%@Id", n];
    NSString* nameVal = nil;
    NSString* idVal = nil;
    BOOL foundName = [Preferences readPreferenceFromDictionary:dict key:nameKey value:&nameVal modifiedDate:nil perDevice:nil];
    BOOL foundId = [Preferences readPreferenceFromDictionary:dict key:idKey value:&idVal modifiedDate:nil perDevice:nil];
    
    if (!foundName && !foundId) // legacy
    {
        NSString* countKey = [NSString stringWithFormat:@"%@%@", n, @"Count"];
        NSString* countVal = nil;
        
        [Preferences readPreferenceFromDictionary:dict key:countKey value:&countVal modifiedDate:nil perDevice:nil];
        if (countVal)
        {
            int numItems = [countVal intValue];
            NSString* hardwareID = [DataModel getInstance].hardwareID;
            BOOL foundHardware = NO;
            for (int i = 0; i < numItems && !foundHardware; i++)
            {
                NSString* prefKey = [NSString stringWithFormat:@"%@%d", n, i];
                NSString* prefVal = nil;
                [Preferences readPreferenceFromDictionary:dict key:prefKey value:&prefVal modifiedDate:nil perDevice:nil];
                
                if (prefVal)
                {
                    NSString* thisHardwareID = nil;
                    ABRecordID thisRecordID = kABRecordInvalidID;
                    NSString* thisName = nil;
                    
                    // Parse the preference string
                    if ([self parseLegacyPreferenceString:prefVal hardwareID:&thisHardwareID recordID:&thisRecordID name:&thisName] &&
                        thisHardwareID &&
                        [thisHardwareID caseInsensitiveCompare:hardwareID] == NSOrderedSame)
                    {
                        if (!thisName)
                            thisName = @"";
                        nameVal = thisName;
                        idVal = [NSString stringWithFormat:@"%d", thisRecordID];
                        foundHardware = YES;
                    }
                }
            }
        }
    }
    
    return [self initInternal:nameVal contactId:idVal name:n contactType:type];
}

// Returns the person name for the given contact
- (NSString*) getPersonNameForContact:(ABRecordRef)record
{
    if (record == NULL)
        return nil;
    
    NSMutableString* n = [NSMutableString stringWithString:@""];
    
    CFStringRef firstName, lastName;
    firstName = ABRecordCopyValue(record, kABPersonFirstNameProperty);
    lastName  = ABRecordCopyValue(record, kABPersonLastNameProperty);
    if (firstName && CFStringGetLength(firstName) > 0)
        [n appendFormat:@"%@", (__bridge NSString*)firstName];
    if (lastName && CFStringGetLength(lastName) > 0)
    {
        if ([n length] > 0)
            [n appendString:@" "];
        [n appendFormat:@"%@", (__bridge NSString*)lastName];
    }
    if (firstName)
        CFRelease(firstName);
    if (lastName)
        CFRelease(lastName);
    
    return n;
}

// Returns the organization name for the given contact
- (NSString*) getOrganizationNameForContact:(ABRecordRef)record
{
    if (record == NULL)
        return nil;
    
    NSMutableString* n = [NSMutableString stringWithString:@""];
    
    CFStringRef orgName;
    orgName = ABRecordCopyValue(record, kABPersonOrganizationProperty);
    if (orgName && CFStringGetLength(orgName) > 0)
        [n appendFormat:@"%@", (__bridge NSString*)orgName];
    if (orgName)
        CFRelease(orgName);
    
    return n;
}

- (NSString*) getNameForContact:(ABRecordID)recordID
{
    NSString* contactName = nil;
    
    // Don't use the addressBook if we're not authorized to
    if ([DataModel getInstance].contactsHelper.addressBook == NULL)
        recordID = kABRecordInvalidID;
    
    if (recordID != kABRecordInvalidID)
    {
        ABRecordRef record = ABAddressBookGetPersonWithRecordID([DataModel getInstance].contactsHelper.addressBook, recordID);
        if (record != NULL)
        {
            if (contactType == AddressBookContactTypePerson)
                contactName = [self getPersonNameForContact:record];
            else if (contactType == AddressBookContactTypeOrganization)
                contactName = [self getOrganizationNameForContact:record];
        }
    }
    
    return contactName;
}

// Parses the given preference string for a hardware ID, record ID, and name. Returns whether successful.
- (BOOL) parseLegacyPreferenceString:(NSString*)prefString // legacy
                    hardwareID:(NSString**)hardwareID
                      recordID:(ABRecordID*)recordID
                          name:(NSString**)n
{
    if (!prefString || !hardwareID || !recordID || !n)
        return NO;
    
    *hardwareID = nil;
    *recordID = kABRecordInvalidID;
    *n = nil;
    
    NSRange firstColonRange = [prefString rangeOfString:@":"];
    if (firstColonRange.location == NSNotFound)
        return NO;
    
    // Extract the hardware ID and the remainder of the string
    NSRange hardwareIDRange = NSMakeRange(0, firstColonRange.location);
    *hardwareID = [prefString substringWithRange:hardwareIDRange];
    NSRange postHardwareIDRange = NSMakeRange(firstColonRange.location+1, [prefString length]-[(*hardwareID) length]-1);
    NSString* postHardwareID = [prefString substringWithRange:postHardwareIDRange];
    
    NSRange secondColonRange = [postHardwareID rangeOfString:@":"];
    if (secondColonRange.location == NSNotFound) // If we couldn't find a second colon, assume everything after the first colon is the record ID
        *recordID = [postHardwareID intValue];
    else // found a second colon
    {
        // Extract the record ID and the name
        NSRange recordIDRange = NSMakeRange(0, secondColonRange.location);
        NSString* recordIDStr = [postHardwareID substringWithRange:recordIDRange];
        *recordID = [recordIDStr intValue];
        NSRange nameRange = NSMakeRange(secondColonRange.location+1, [postHardwareID length]-[recordIDStr length]-1);
        *n = [postHardwareID substringWithRange:nameRange];
    }
    
    return YES;
}

- (ABRecordID) lookupRecordIDByName:(NSString*)recordName
{
    ABRecordID recordID = kABRecordInvalidID;
    
    if ([DataModel getInstance].contactsHelper.addressBook != NULL)
    {
        NSArray *candidates = (NSArray *)CFBridgingRelease(ABAddressBookCopyPeopleWithName([DataModel getInstance].contactsHelper.addressBook, (__bridge CFStringRef)recordName));
        
        if (candidates != nil)
        {
            int numCandidates = (int)[candidates count];
            for (int i = 0; i < numCandidates && recordID == kABRecordInvalidID; i++)
            {
                ABRecordRef record = (__bridge ABRecordRef)[candidates objectAtIndex:i];
                ABRecordID thisRecordID = ABRecordGetRecordID(record);
                
                // Test whether this is a valid candidate
                if ([self isValidContact:thisRecordID])
                    recordID = thisRecordID;
            }
        }
    }
    
    return recordID;
}

- (void) refreshValues
{
    if ([addressBookContactName length] == 0)
    {
        if ([addressBookContactId length] > 0) // clear the record ID
        {
            addressBookContactId = @"";
        }
        return;
    }
    
    if ([addressBookContactId length] == 0) // Generate record ID from name via lookup
    {
        ABRecordID recordID = [self lookupRecordIDByName:addressBookContactName];
        if (recordID != kABRecordInvalidID)
        {
            addressBookContactId = [NSString stringWithFormat:@"%d", recordID];
        }
    }
    else
    {
        ABRecordID recordID = [addressBookContactId intValue];
        NSString* recordIDName = [self getNameForContact:recordID];
        if (!recordIDName || [recordIDName length] == 0) // check if this record ID is still valid
        {
            recordID = [self lookupRecordIDByName:addressBookContactName];
            if (recordID != kABRecordInvalidID)
                addressBookContactId = [NSString stringWithFormat:@"%d", recordID];
            else
                addressBookContactId = @"";
        }
        else if (![recordIDName isEqualToString:addressBookContactName]) // check if record has been edited outside the app. If so, update the name.
        {
            addressBookContactName = recordIDName;
            if (delegate && [delegate respondsToSelector:@selector(addressBookContactChanged)])
                [delegate addressBookContactChanged];
        }
    }
}




// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{
    [self refreshValues];
    
    NSString* nameKey = [NSString stringWithFormat:@"%@Name", name];
    NSString* idKey = [NSString stringWithFormat:@"%@Id", name];

    [Preferences populatePreferenceInDictionary:dict key:nameKey value:addressBookContactName modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:idKey value:addressBookContactId modifiedDate:nil perDevice:YES];
}

- (NSString*)name
{
    return name;
}

- (AddressBookContactType)contactType
{
    return contactType;
}

- (ABRecordID) recordID
{
    [self refreshValues];
    
    ABRecordID recordID = kABRecordInvalidID;

    if ([addressBookContactId length] > 0)
        recordID = [addressBookContactId intValue];
    
   return recordID;
}

- (void)setRecordID:(ABRecordID)rID
{
    NSString* recordIdStr = nil;
    NSString* recordName = nil;

    if (rID != kABRecordInvalidID)
    {
        NSString* contactName = [self getNameForContact:rID];
        if (contactName && [contactName length] > 0)
        {
            recordIdStr = [NSString stringWithFormat:@"%d", rID];
            recordName = contactName;
        }
        else
        {
            recordIdStr = @"";
            recordName = @"";
        }
    }
    else
    {
        recordIdStr = @"";
        recordName = @"";
    }
    
    addressBookContactId = recordIdStr;
    if (![recordName isEqualToString:addressBookContactName])
    {
        addressBookContactName = recordName;
    
        if (delegate && [delegate respondsToSelector:@selector(addressBookContactChanged)])
            [delegate addressBookContactChanged];
    }
}

// Get the name to display
- (NSString*) getDisplayName
{
    ABRecordID recordID = self.recordID;
    if (recordID == kABRecordInvalidID)
        return nil;
    
    NSMutableString* displayName = [NSMutableString stringWithString:@""];
    
    if ([DataModel getInstance].contactsHelper.addressBook == NULL)
        return nil;
    
    ABRecordRef record = ABAddressBookGetPersonWithRecordID([DataModel getInstance].contactsHelper.addressBook, recordID);
    if (record == NULL)
    {
        return nil;
    }
    
    if (contactType == AddressBookContactTypePerson)
    {
        // Append the first/middle/last name with prefix & suffix
        CFStringRef firstName, middleName, lastName, prefix, suffix;
        firstName = ABRecordCopyValue(record, kABPersonFirstNameProperty);
        middleName = ABRecordCopyValue(record, kABPersonMiddleNameProperty);
        lastName = ABRecordCopyValue(record, kABPersonLastNameProperty);
        prefix = ABRecordCopyValue(record, kABPersonPrefixProperty);
        suffix = ABRecordCopyValue(record, kABPersonSuffixProperty);
        if (prefix && CFStringGetLength(prefix) > 0)
            [displayName appendString:(__bridge NSString*)prefix];
        if (firstName && CFStringGetLength(firstName) > 0)
        {
            if ([displayName length] > 0)
                [displayName appendString:@" "];
            [displayName appendString:(__bridge NSString*)firstName];
        }
        if (middleName && CFStringGetLength(middleName) > 0)
        {
            if ([displayName length] > 0)
                [displayName appendString:@" "];
            [displayName appendString:(__bridge NSString*)middleName];
        }
        if (lastName && CFStringGetLength(lastName) > 0)
        {
            if ([displayName length] > 0)
                [displayName appendString:@" "];
            [displayName appendString:(__bridge NSString*)lastName];
        }
        if (suffix && CFStringGetLength(suffix) > 0)
        {
            if ([displayName length] > 0)
                [displayName appendString:@" "];
            [displayName appendString:(__bridge NSString*)suffix];
        }
        if (firstName)
            CFRelease(firstName);
        if (middleName)
            CFRelease(middleName);
        if (lastName)
            CFRelease(lastName);
        if (prefix)
            CFRelease(prefix);
        if (suffix)
            CFRelease(suffix);
    }
    else // AddressBookContactTypeOrganization
    {
        CFStringRef orgName;
        orgName = ABRecordCopyValue(record, kABPersonOrganizationProperty);
        if (orgName && CFStringGetLength(orgName) > 0)
            [displayName appendString:(__bridge NSString*)orgName];
        if (orgName)
            CFRelease(orgName);
    }
    
    return displayName;
}

// Returns whether the given record ID is a valid contact (the same type as this instance)
- (BOOL) isValidContact:(ABRecordID)recordID
{
    NSString* contactName = [self getNameForContact:recordID];
    return (contactName && [contactName length] > 0);
}

@end
