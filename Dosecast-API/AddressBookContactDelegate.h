//
//  AddressBookContactDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 

@protocol AddressBookContactDelegate

@required

// Notifies when a contact has been changed
- (void)addressBookContactChanged;

@end
