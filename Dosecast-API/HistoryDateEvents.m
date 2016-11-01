//
//  HistoryDateEvents.m
//  Dosecast
//
//  Created by Jonathan Levene on 7/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "HistoryDateEvents.h"
#import "EditableHistoryEvent.h"
#import "HistoryEvent.h"

@implementation HistoryDateEvents
@synthesize creationDate;
@synthesize editableHistoryEvents;

- (id)init
{
    return [self init:nil editableHistoryEvents:nil];	
}

- (id)init:(NSDate*)d editableHistoryEvents:(NSArray*)editableEvents
{
	if ((self = [super init]))
    {
		creationDate = d;
		editableHistoryEvents = [[NSMutableArray alloc] initWithArray:editableEvents];
	}
	
    return self;		
}

// Build history date events with the given editable history event
+ (HistoryDateEvents*) historyDateEventsWithEditableHistoryEvent:(EditableHistoryEvent*)event
{
	if (!event)
		return nil;
	else
	{
		return [[HistoryDateEvents alloc] init:event.creationDate
						  editableHistoryEvents:[NSArray arrayWithObjects:event, nil]];
	}
}

// Build history date events list from the given sorted event list
+ (NSArray*) historyDateEventsListFromHistoryEvents:(NSArray*)sortedEvents
{
	if (!sortedEvents)
		return [[NSArray alloc] init];
	
	int numEvents = (int)[sortedEvents count];
	NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
	NSMutableArray* dateEvents = [[NSMutableArray alloc] init];
	if (numEvents > 0)
	{
		HistoryEvent* event = [sortedEvents lastObject];
		HistoryDateEvents* newDateEvents = [[HistoryDateEvents alloc] init:event.creationDate editableHistoryEvents:nil];
		[dateEvents addObject:newDateEvents];
	}
	
	for (int i = numEvents-1; i >= 0; i--)
	{
		HistoryEvent* event = [sortedEvents objectAtIndex:i];
		HistoryDateEvents* lastDateEvents = [dateEvents lastObject];
		
		// Decide whether to add this event to the lastDateEvents
		NSDateComponents* thisDateComponents = [cal components:unitFlags fromDate:event.creationDate];
		NSDateComponents* lastDateComponents = [cal components:unitFlags fromDate:lastDateEvents.creationDate];
		if ([thisDateComponents day] == [lastDateComponents day] &&
			[thisDateComponents month] == [lastDateComponents month] &&
			[thisDateComponents year] == [lastDateComponents year])
		{
			[lastDateEvents.editableHistoryEvents addObject:
			 [EditableHistoryEvent editableHistoryEventWithHistoryEvent:event]];
		}
		else
		{
			[dateEvents addObject:
			 [HistoryDateEvents historyDateEventsWithEditableHistoryEvent:
			  [EditableHistoryEvent editableHistoryEventWithHistoryEvent:event]]];
		}
	}
	
	return dateEvents;
}


@end
