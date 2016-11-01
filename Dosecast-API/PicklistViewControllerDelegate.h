//
//  PicklistViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

@class PicklistEditedItem;

@protocol PicklistViewControllerDelegate

@required

// Returns whether to allow the controller to be popped
- (BOOL)handleDonePickingItemInList:(int)item value:(NSString*)value identifier:(NSString*)Id subIdentifier:(NSString*)subId;

@optional

// Called when user hits cancel
- (void)handlePickCancel:(NSString*)Id subIdentifier:(NSString*)subId;

// Called when an item is deleted. Returns whether should be allowed.
- (BOOL)allowItemDeletion:(int)item value:(NSString*)value identifier:(NSString*)Id subIdentifier:(NSString*)subId;

// Called when an item is created. Returns whether should be allowed.
- (BOOL)allowItemCreation:(NSString*)itemName identifier:(NSString*)Id subIdentifier:(NSString*)subId;

// Called when a duplicate item is created. Returns whether should be allowed.
- (BOOL)handleDuplicateItemCreation:(NSString*)Id subIdentifier:(NSString*)subId;

// Called when an item is selected
- (void)handleSelectItemInList:(int)item value:(NSString*)value identifier:(NSString*)Id subIdentifier:(NSString*)subId;

// Called to request item deletion, renaming, and creation. Items in each array are instances
// of PicklistEditedItem. Once changes have been made, must call PicklistViewController commitEdits
- (void)handleRequestEditItems:(NSArray*)deletedItems // deleted item indices are relative to the original editableItems list passed-in to PicklistViewController init
                  renamedItems:(NSArray*)renamedItems // renamed item indices are relative to the original editableItems list *post-deletions* (i.e. assuming the deleted items have already been applied)
                  createdItems:(NSArray*)createdItems // created item indices are relative to the original editableItems list *post-deletions* (i.e. assuming the deleted items have already been applied)
                    identifier:(NSString*)Id
                 subIdentifier:(NSString*)subId;

@end
