//
//  TextEntryViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

@protocol TextEntryViewControllerDelegate

@required

// Callback for text entry. Returns whether the new values are accepted.
- (BOOL)handleTextEntryDone:(NSArray*)textValues
                 identifier:(NSString*)Id // a unique identifier for the current text
              subIdentifier:(NSString*)subId; // a unique identifier for the current text

@end
