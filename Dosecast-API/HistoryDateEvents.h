//
//  HistoryDateEvents.h
//  Dosecast
//
//  Created by Jonathan Levene on 7/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class EditableHistoryEvent;
@interface HistoryDateEvents : NSObject
{
@private
	NSDate* creationDate;				   // a representative day
	NSMutableArray* editableHistoryEvents; // the editable events on the given day
}

- (id)init:(NSDate*)d editableHistoryEvents:(NSArray*)editableEvents;

// Build history date events with the given editable history event
+ (HistoryDateEvents*) historyDateEventsWithEditableHistoryEvent:(EditableHistoryEvent*)event;

// Build history date events list from the given sorted event list
+ (NSArray*) historyDateEventsListFromHistoryEvents:(NSArray*)sortedEvents;

@property (nonatomic, strong) NSDate* creationDate;
@property (nonatomic, strong) NSMutableArray* editableHistoryEvents;

@end
