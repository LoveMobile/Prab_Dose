//
//  PicklistViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "PicklistViewController.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "PicklistEditedItem.h"
#import "TextEntryViewController.h"

static const CGFloat LABEL_BASE_HEIGHT = 17.25f;
static const CGFloat CELL_MIN_HEIGHT = 44.0f;

@implementation PicklistViewController

@synthesize tableView;
@synthesize checkboxCell;
@synthesize addItemCell;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil nonEditableItems:nil editableItems:nil selectedItem:-1 allowEditing:NO viewTitle:nil headerText:nil footerText:nil addItemCellText:nil addItemPlaceholderText:nil displayNone:NO identifier:nil subIdentifier:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
     nonEditableItems:(NSArray*)nei
        editableItems:(NSArray*)ei
		 selectedItem:(int)s
         allowEditing:(BOOL)editing
			viewTitle:(NSString*)title
		   headerText:(NSString*)header
		   footerText:(NSString*)footer
      addItemCellText:(NSString*)addItemText
addItemPlaceholderText:(NSString*)addPlaceholderText
		  displayNone:(BOOL)displayNone
		   identifier:(NSString*)Id
		subIdentifier:(NSString*)subId
			 delegate:(NSObject<PicklistViewControllerDelegate>*)d
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
        if (!nei)
            nei = [[NSArray alloc] init];
		nonEditableItems = [[NSArray alloc] initWithArray:nei];
        if (!ei)
            ei = [[NSArray alloc] init];            
        editableItems = [[NSMutableArray alloc] initWithArray:ei];
		selectedItem = s;
		delegate = d;
		headerText = header;
		footerText = footer;
		self.title = title;
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

        viewTitle = title;
		identifier = Id;
		subIdentifier = subId;
		displayNoneButton = displayNone;
        allowEditing = editing;
        addItemCellText = addItemText;
        addItemPlaceholderText = addPlaceholderText;
        renamedItems = [[NSMutableArray alloc] init];
        deletedItems = [[NSMutableArray alloc] init];
        createdItems = [[NSMutableArray alloc] init];
        editedItems = [[NSMutableArray alloc] initWithArray:editableItems];
        isEditing = NO;
        exampleCheckboxCell = nil;
        
        NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
        doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
        self.hidesBottomBarWhenPushed = !displayNone && !editing;
   }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;	
    tableView.allowsSelectionDuringEditing = YES;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	// Set Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
	// Set Done button
	self.navigationItem.rightBarButtonItem = doneButton;
	
	// Create toolbar for edit/none button
	if (displayNoneButton || allowEditing)
	{
        NSMutableArray *toolbarItems = [[NSMutableArray alloc] init];
        if (allowEditing)
        {
            NSString* editButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonEdit", @"Dosecast", [DosecastUtil getResourceBundle], @"Edit", @"The text on the Edit toolbar button"]);
            UIBarButtonItem* editButton = [[UIBarButtonItem alloc] initWithTitle:editButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleEdit:)];
            [toolbarItems addObject:editButton];
        }
        UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        [toolbarItems addObject:flexSpaceButton];
        if (displayNoneButton)
        {
            NSString* noneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonNone", @"Dosecast", [DosecastUtil getResourceBundle], @"None", @"The text on the None toolbar button"]);
            UIBarButtonItem *noneButton = [[UIBarButtonItem alloc] initWithTitle:noneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleNone:)];
            [toolbarItems addObject:noneButton];
        }
		self.toolbarItems = toolbarItems;	
	}
    
    // Load an example cell
    [[DosecastUtil getResourceBundle] loadNibNamed:@"PicklistViewCell" owner:self options:nil];
    exampleCheckboxCell = checkboxCell;
    checkboxCell = nil;
}

- (void) recalcExampleCellWidth
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    int screenWidth = 0;
    if (self.interfaceOrientation == UIInterfaceOrientationPortrait ||
        self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        screenWidth = screenBounds.size.width;
    }
    else
        screenWidth = screenBounds.size.height;
    
    if (isEditing)
        screenWidth -= 100; // Remove space for disclosure indicator and delete button
    
    exampleCheckboxCell.frame = CGRectMake(exampleCheckboxCell.frame.origin.x, exampleCheckboxCell.frame.origin.y, screenWidth, exampleCheckboxCell.frame.size.height);
    [exampleCheckboxCell layoutIfNeeded];
}

- (void) updateDoneButtonEnabled
{
    doneButton.enabled = (isEditing || selectedItem >= 0 || displayNoneButton);
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];	
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
		
    self.navigationController.navigationBar.barTintColor = [DosecastUtil getNavigationBarColor];
    self.navigationController.toolbar.barTintColor = [DosecastUtil getToolbarColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.toolbar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
    
    [self updateDoneButtonEnabled];
    
    if (self.hidesBottomBarWhenPushed != self.navigationController.toolbarHidden)
        [self.navigationController setToolbarHidden:self.hidesBottomBarWhenPushed];
}


- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate
{
    return YES;
}


// Function to compare two PicklistEditedItems
NSComparisonResult comparePicklistEditedItems(PicklistEditedItem* p1, PicklistEditedItem* p2, void* context)
{
    if (p1.index < p2.index)
        return NSOrderedAscending;
    else if (p1.index > p2.index)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

// Calculates the new deleted items index for the given index (in a different list)
- (int) calculateDeletedItemsIndexForNewIndex:(int)index inList:(NSArray*)list
{
    int numItems = (int)[list count];
    BOOL done = NO;
    int newIndex = index;
    
    for (int i = 0; i < numItems && !done; i++)
    {
        PicklistEditedItem* item = [list objectAtIndex:i];
        if (newIndex >= item.index)
            newIndex += 1;
        else if (newIndex < item.index)
            done = YES;
    }
    
    return newIndex;
}

- (PicklistEditedItem*) findPicklistEditedItemWithIndex:(int)index inList:(NSArray*)list foundPosition:(int*)position
{
    int numItems = (int)[list count];
    PicklistEditedItem* foundItem = nil;
    if (position)
        *position = -1;
    
    for (int i = 0; i < numItems && !foundItem; i++)
    {
        PicklistEditedItem* item = [list objectAtIndex:i];
        if (item.index == index)
        {
            foundItem = item;
            if (position)
                *position = i;
        }
    }
    
    return foundItem;
}

- (int) findNumSmallerIndexesThan:(int)index inList:(NSArray*)list
{
    int numItems = (int)[list count];
    int numSmallerIndexes = 0;
    
    for (int i = 0; i < numItems; i++)
    {
        PicklistEditedItem* item = [list objectAtIndex:i];
        if (item.index < index)
        {
            numSmallerIndexes += 1;
        }
    }
    
    return numSmallerIndexes;
}

// Decrements the index for all items with indexes greater than the given index
- (void)decrementIndexesForPicklistEditedItemsWithIndexGreaterThan:(int)index inList:(NSArray*)list
{
    int numItems = (int)[list count];
    
    for (int i = 0; i < numItems; i++)
    {
        PicklistEditedItem* item = [list objectAtIndex:i];
        if (item.index > index)
            item.index -= 1;
    }    
}

// Update the list of edited items - including all edits in-progress
- (void) updateEditedItems
{    
    // Start with all editable items
    [editedItems removeAllObjects];    
    [editedItems addObjectsFromArray:editableItems];
    
    // Remove deleted items
    int offsetIndex = 0;
    int numDeletedItems = (int)[deletedItems count];
    for (int i = 0; i < numDeletedItems; i++)
    {
        PicklistEditedItem* item = [deletedItems objectAtIndex:i];
        int index = item.index + offsetIndex;
        [editedItems removeObjectAtIndex:index];
        offsetIndex -= 1;
    }
    
    // Apply renamed items
    int numRenamedItems = (int)[renamedItems count];
    for (int i = 0; i < numRenamedItems; i++)
    {
        PicklistEditedItem* item = [renamedItems objectAtIndex:i];
        [editedItems replaceObjectAtIndex:item.index withObject:item.value];
    }

    // Add created items
    int numCreatedItems = (int)[createdItems count];
    for (int i = 0; i < numCreatedItems; i++)
    {
        PicklistEditedItem* item = [createdItems objectAtIndex:i];
        [editedItems addObject:item.value];
    }
}

- (void) setIsEditing:(BOOL)editing
{
    if (editing == isEditing)
        return;
        
    [tableView beginUpdates];
    
    isEditing = editing;
    tableView.editing = isEditing;
    [self.navigationController setToolbarHidden:isEditing animated:YES];

    // Give a visual indication that something is happening by reloading the non editable section (if present)
    if ([nonEditableItems count] > 0)
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationLeft];  
        
    [tableView endUpdates];
    
    [self updateDoneButtonEnabled];
}

- (void) reloadEditableRows
{
    int currentSection = 0;
    if ([nonEditableItems count] > 0)
        currentSection = 1;
    
    NSMutableArray* reloadedIndexPaths = [[NSMutableArray alloc] init];
    int numEditableItems = (int)[editableItems count];
    for (int i = 0; i < numEditableItems; i++)
    {
        [reloadedIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:currentSection]];
    }
    
    [tableView reloadRowsAtIndexPaths:reloadedIndexPaths withRowAnimation:UITableViewRowAnimationLeft];
}

// called to commit pending renames and deletes
- (void) commitEdits:(NSArray*)deleted // deleted item indices are relative to the original editableItems list passed-in to PicklistViewController init
        renamedItems:(NSArray*)renamed // renamed item indices are relative to the original editableItems list *post-deletions* (i.e. assuming the deleted items have already been applied)
        createdItems:(NSArray*)created // created item indices are relative to the original editableItems list *post-deletions* (i.e. assuming the deleted items have already been applied)
{
    BOOL wasEditing = isEditing;
    
    // Find the text entry view controller in the view stack
    UIViewController* textEntryController = nil;
    NSArray* viewControllers = self.navigationController.viewControllers;
    int numViewControllers = (int)[viewControllers count];
    for (int i = 0; i < (numViewControllers-1) && !textEntryController; i++)
    {
        UIViewController* thisController = (UIViewController*)[viewControllers objectAtIndex:i];
        if ([thisController isKindOfClass:[PicklistViewController class]])
        {
            UIViewController* topController = (UIViewController*)[viewControllers objectAtIndex:i+1];
            if ([topController isKindOfClass:[TextEntryViewController class]])
                textEntryController = topController;
        }
    }

    // If the text entry view controller is still active, pop it now
    if (textEntryController)
        [self.navigationController popViewControllerAnimated:YES];
    
    [deletedItems setArray:deleted];
    [renamedItems setArray:renamed];
    [createdItems setArray:created];

    // Handle any selectedItem change that might occur.
    if (selectedItem >= 0)
    {
        PicklistEditedItem* deletedItem = [self findPicklistEditedItemWithIndex:(selectedItem-(int)[nonEditableItems count]) inList:deletedItems foundPosition:nil];
        if (deletedItem) // if we found that the selected item was deleted
        {
            selectedItem = -1;
            [self updateDoneButtonEnabled];
        }
        else
        {
            // If any items are deleted earlier than the selected item, the selected item index will need to be decremented.
            selectedItem -= [self findNumSmallerIndexesThan:(selectedItem-(int)[nonEditableItems count]) inList:deletedItems];
        }
    }

    [tableView beginUpdates];
    
    [self updateEditedItems];

    if (!isEditing)
    {
        int currentSection = 0;
        if ([nonEditableItems count] > 0)
            currentSection = 1;

        // Remove deleted cells
        int numDeletedItems = (int)[deletedItems count];
        NSMutableArray* deletedIndexPaths = [[NSMutableArray alloc] init];
        for (int i = 0; i < numDeletedItems; i++)
        {
            PicklistEditedItem* item = [deletedItems objectAtIndex:i];
            [deletedIndexPaths addObject:[NSIndexPath indexPathForRow:item.index inSection:currentSection]];
        }
        [tableView deleteRowsAtIndexPaths:deletedIndexPaths withRowAnimation:UITableViewRowAnimationLeft];

        // Reload renamed cells
        int numRenamedCells = (int)[renamedItems count];
        NSMutableArray* renamedIndexPaths = [[NSMutableArray alloc] init];
        for (int i = 0; i < numRenamedCells; i++)
        {
            PicklistEditedItem* item = [renamedItems objectAtIndex:i];
            [renamedIndexPaths addObject:[NSIndexPath indexPathForRow:item.index inSection:currentSection]];
        }
        [tableView reloadRowsAtIndexPaths:renamedIndexPaths withRowAnimation:UITableViewRowAnimationLeft];
        
        // Add created cells
        int numCreatedCells = (int)[createdItems count];
        NSMutableArray* createdIndexPaths = [[NSMutableArray alloc] init];
        for (int i = 0; i < numCreatedCells; i++)
        {
            PicklistEditedItem* item = [createdItems objectAtIndex:i];
            [createdIndexPaths addObject:[NSIndexPath indexPathForRow:item.index inSection:currentSection]];
        }
        [tableView insertRowsAtIndexPaths:createdIndexPaths withRowAnimation:UITableViewRowAnimationRight];
    }
    
    // Simply take the items from the editedItems list
    [editableItems removeAllObjects];
    [editableItems addObjectsFromArray:editedItems];
        
    [deletedItems removeAllObjects];
    [renamedItems removeAllObjects];
    [createdItems removeAllObjects];

    if (isEditing)
    {
        [self setIsEditing:NO];
        [self reloadEditableRows];
    }
    
    [tableView endUpdates];
    
    if (!wasEditing && [created count] > 0)
    {
        // Select the last created item
        NSIndexPath* indexPath = nil;
        if ([nonEditableItems count] > 0)
            indexPath = [NSIndexPath indexPathForRow:([editableItems count]-1) inSection:1];
        else
            indexPath = [NSIndexPath indexPathForRow:([editableItems count]-1) inSection:0];
        
        [self handleNonEditingCellSelection:indexPath];
    }
}

- (IBAction)handleDone:(id)sender
{
    if (isEditing)
    {        
        // If we have any changes, inform the delegate (if we can)
        if ([renamedItems count] > 0 ||
            [deletedItems count] > 0 ||
            [createdItems count] > 0)
        {
            if (delegate && [delegate respondsToSelector:@selector(handleRequestEditItems:renamedItems:createdItems:identifier:subIdentifier:)])
            {
                [delegate handleRequestEditItems:deletedItems renamedItems:renamedItems createdItems:createdItems identifier:identifier subIdentifier:subIdentifier];
            }
            else
                [self commitEdits:deletedItems renamedItems:renamedItems createdItems:createdItems];
        }
        else
        {
            [tableView beginUpdates];
            [self setIsEditing:NO];
            [self reloadEditableRows];
            [tableView endUpdates];
        }
    }
    else
    {
        NSString* selectedValue = nil;
        if (selectedItem >= 0)
        {
            if (selectedItem < [nonEditableItems count])
                selectedValue = [nonEditableItems objectAtIndex:selectedItem];
            else if ([editableItems count] > (selectedItem-[nonEditableItems count]))
                selectedValue = [editableItems objectAtIndex:selectedItem-[nonEditableItems count]];
        }
        
        if (selectedValue)
        {
            BOOL allowPop = YES;
            if (delegate && [delegate respondsToSelector:@selector(handleDonePickingItemInList:value:identifier:subIdentifier:)])
            {
                allowPop = [delegate handleDonePickingItemInList:selectedItem value:selectedValue identifier:identifier subIdentifier:subIdentifier];
            }
            if (allowPop)
                [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

- (IBAction)handleCancel:(id)sender
{
    if (isEditing)
    {
        int currentSection = 0;
        if ([nonEditableItems count] > 0)
            currentSection = 1;
        
        // Delete the items that were created
        NSMutableArray* deletedIndexPaths = [[NSMutableArray alloc] init];
        int numCreatedItems = (int)[createdItems count];
        for (int i = 0; i < numCreatedItems; i++)
        {
            PicklistEditedItem* item = [createdItems objectAtIndex:i];
            [deletedIndexPaths addObject:[NSIndexPath indexPathForRow:item.index inSection:currentSection]];
        }

        // Reload the items that were renamed
        NSMutableArray* renamedIndexPaths = [[NSMutableArray alloc] init];
        int numRenamedItems = (int)[renamedItems count];
        for (int i = 0; i < numRenamedItems; i++)
        {
            PicklistEditedItem* item = [renamedItems objectAtIndex:i];
            [renamedIndexPaths addObject:[NSIndexPath indexPathForRow:item.index inSection:currentSection]];
        }

        // Insert back the items that were deleted
        NSMutableArray* insertedIndexPaths = [[NSMutableArray alloc] init];
        int numDeletedItems = (int)[deletedItems count];
        for (int i = 0; i < numDeletedItems; i++)
        {
            PicklistEditedItem* item = [deletedItems objectAtIndex:i];
            [insertedIndexPaths addObject:[NSIndexPath indexPathForRow:item.index inSection:currentSection]];
        }

        [deletedItems removeAllObjects];
        [renamedItems removeAllObjects];
        [createdItems removeAllObjects];
        
        [tableView beginUpdates];

        [self updateEditedItems];

        [self setIsEditing:NO];
        [tableView deleteRowsAtIndexPaths:deletedIndexPaths withRowAnimation:UITableViewRowAnimationLeft];
        [tableView reloadRowsAtIndexPaths:renamedIndexPaths withRowAnimation:UITableViewRowAnimationLeft];
        [tableView insertRowsAtIndexPaths:insertedIndexPaths withRowAnimation:UITableViewRowAnimationRight];
        
        [tableView endUpdates];
    }
    else
    {
        if (delegate && [delegate respondsToSelector:@selector(handlePickCancel:subIdentifier:)])
        {
            [delegate handlePickCancel:identifier subIdentifier:subIdentifier];
        }

        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)handleEdit:(id)sender
{
    [self setIsEditing:YES];
}

- (void)handleNone:(id)sender
{
	BOOL allowPop = YES;
	if (delegate && [delegate respondsToSelector:@selector(handleDonePickingItemInList:value:identifier:subIdentifier:)])
	{
		allowPop = [delegate handleDonePickingItemInList:-1 value:nil identifier:identifier subIdentifier:subIdentifier];
	}
	if (allowPop)
		[self.navigationController popViewControllerAnimated:YES];				
}

-(void) handleRequestEditItemsOrCommit:(NSTimer*)theTimer
{
    NSArray* allItems = (NSArray*)theTimer.userInfo;
    NSArray* deleted = [allItems objectAtIndex:0];
    NSArray* renamed = [allItems objectAtIndex:1];
    NSArray* created = [allItems objectAtIndex:2];
    
    if (delegate && [delegate respondsToSelector:@selector(handleRequestEditItems:renamedItems:createdItems:identifier:subIdentifier:)])
    {
        [delegate handleRequestEditItems:deleted renamedItems:renamed createdItems:created identifier:identifier subIdentifier:subIdentifier];
    }
    else
    {
        [self commitEdits:deleted renamedItems:renamed createdItems:created];
    }
}

// Callback for text entry. Returns whether the new values are accepted.
- (BOOL)handleTextEntryDone:(NSArray*)textValues
                 identifier:(NSString*)Id // a unique identifier for the current text
              subIdentifier:(NSString*)subId // a unique identifier for the current text
{
    if (!Id)
        return NO;
    
    NSString* value = [textValues objectAtIndex:0];

    // See if our delegate will allow this value
    BOOL allowCreation = YES;
    if (delegate && [delegate respondsToSelector:@selector(allowItemCreation:identifier:subIdentifier:)])
    {
        allowCreation = [delegate allowItemCreation:value identifier:identifier subIdentifier:subIdentifier];
    }
    if (!allowCreation)
        return NO;
    
    int itemPosition = [Id intValue];
    BOOL foundDuplicate = NO;
    
    // Look for duplicates among edited & nonEditable items
    int numItems = (int)[nonEditableItems count];
    for (int i = 0; i < numItems && !foundDuplicate; i++)
    {
        NSString* itemName = [nonEditableItems objectAtIndex:i];
        if ([itemName caseInsensitiveCompare:value] == NSOrderedSame)
            foundDuplicate = YES;
    }
    
    numItems = (int)[editedItems count];
    for (int i = 0; i < numItems && !foundDuplicate; i++)
    {
        NSString* itemName = [editedItems objectAtIndex:i];
        if (i != itemPosition && [itemName caseInsensitiveCompare:value] == NSOrderedSame)
            foundDuplicate = YES;
    }
    
    // If we found a duplicate, see if our delegate wants to allow this
    if (foundDuplicate && delegate && [delegate respondsToSelector:@selector(handleDuplicateItemCreation:subIdentifier:)])
    {
        allowCreation = [delegate handleDuplicateItemCreation:identifier subIdentifier:subIdentifier];
    }
    if (!allowCreation)
        return NO;
    
    int currentSection = 0;
    if ([nonEditableItems count] > 0)
        currentSection = 1;

    if (itemPosition == [editedItems count]) // if we're adding
    {
        PicklistEditedItem* newItem = [[PicklistEditedItem alloc] init:value index:itemPosition];
                    
        // If we're editing, insert a new row. The delegate will get notified when the user taps 'Done'
        if (isEditing)
        {                            
            [createdItems addObject:newItem];

            [self updateEditedItems];

            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:itemPosition inSection:currentSection]]
                             withRowAnimation:UITableViewRowAnimationRight];                
        }
        else // If we're not editing, we just added an item - and therefore need to inform the delegate to get it committed
        {
            NSMutableArray* newCreatedItems = [NSMutableArray arrayWithArray:createdItems];
            [newCreatedItems addObject:newItem];
            
            NSArray* allItems = [NSArray arrayWithObjects:deletedItems, renamedItems, newCreatedItems, nil];
            
            // Inform asynchronously so we can tell the text view controller not to pop yet
            [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleRequestEditItemsOrCommit:) userInfo:allItems repeats:NO];
            
            return NO;
        }
    }
    else // we're editing an existing one
    {            
        // Check among newly created items
        PicklistEditedItem* existingItem = [self findPicklistEditedItemWithIndex:itemPosition inList:createdItems foundPosition:nil];
        if (existingItem)
        {
            existingItem.value = value;
            
            [self updateEditedItems];

            [tableView reloadData];
        }
        else
        {
            // Check among already renamed items
            existingItem = [self findPicklistEditedItemWithIndex:itemPosition inList:renamedItems foundPosition:nil];
            if (existingItem)
            {
                existingItem.value = value;
                
                [self updateEditedItems];

                [tableView reloadData];
            }
            else
            {
                // Create a new renamed item
                PicklistEditedItem* newItem = [[PicklistEditedItem alloc] init:value index:itemPosition];
                [renamedItems addObject:newItem];
                
                [self updateEditedItems];

                [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:itemPosition inSection:currentSection]]
                                 withRowAnimation:UITableViewRowAnimationLeft];
            }
        }
                    
        // Assume we're editing - the delegate will get notified when the user taps 'Done'
    }
    
    return YES;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [self recalcExampleCellWidth];

    int totalSections = 0;
    
    if ([nonEditableItems count] > 0)
        totalSections += 1;
    
    if ([editedItems count] > 0 || allowEditing)
        totalSections += 1;
    
	return totalSections;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        if ([nonEditableItems count] > 0)
            return [nonEditableItems count];
        else
            return [editedItems count]+1; // add one for the Add Item cell
    }
    else // section 1
        return [editedItems count]+1; // add one for the Add Item cell
}

- (UITableViewCell *) createNewItemCell
{
    static NSString *MyIdentifier = @"PillCellIdentifier";

    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        [[DosecastUtil getResourceBundle] loadNibNamed:@"PicklistViewCell" owner:self options:nil];
        cell = checkboxCell;
        checkboxCell = nil;
    }
    
    return cell;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && [nonEditableItems count] > 0)
    {
        UITableViewCell* cell = [self createNewItemCell];
        
        // Set main label
        UILabel* mainLabel = (UILabel *)[cell viewWithTag:1];
        mainLabel.text = [nonEditableItems objectAtIndex:indexPath.row];
        
        // Determine whether checked
        if (indexPath.row == selectedItem && !isEditing)
            cell.accessoryType = UITableViewCellAccessoryCheckmark;	
        else
            cell.accessoryType = UITableViewCellAccessoryNone;	
        cell.editingAccessoryType = UITableViewCellAccessoryNone;
        
        if (isEditing)
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        else
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
        return cell;
    }
    else if ((indexPath.section == 0 && [nonEditableItems count] == 0) || indexPath.section == 1)
    {
        if (indexPath.row == [editedItems count])
        {
            // Set main label
            UILabel* mainLabel = (UILabel *)[addItemCell viewWithTag:1];
            mainLabel.text = addItemCellText;

            addItemCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;	
            addItemCell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            addItemCell.selectionStyle = UITableViewCellSelectionStyleGray;

            return addItemCell;
        }
        else
        {
            UITableViewCell* cell = [self createNewItemCell];
            
            // Set main label
            UILabel* mainLabel = (UILabel *)[cell viewWithTag:1];
            mainLabel.text = [editedItems objectAtIndex:indexPath.row];
            
            // Determine whether checked
            if ((indexPath.row + [nonEditableItems count] == selectedItem) && !isEditing)
                cell.accessoryType = UITableViewCellAccessoryCheckmark;	
            else
                cell.accessoryType = UITableViewCellAccessoryNone;	
            cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;

            return cell;
        }
    }
    else
        return nil;
}

- (CGFloat) getHeightForCellLabelTag:(int)tag labelBaseHeight:(CGFloat)labelBaseHeight withString:(NSString*)value
{
    UILabel* label = (UILabel*)[exampleCheckboxCell viewWithTag:tag];
    CGSize labelMaxSize = CGSizeMake(label.frame.size.width, labelBaseHeight * (float)label.numberOfLines);
    CGRect rect = [value boundingRectWithSize:labelMaxSize
                                      options:NSStringDrawingUsesLineFragmentOrigin
                                   attributes:@{NSFontAttributeName: label.font}
                                      context:nil];
    CGSize labelSize = CGSizeMake(ceilf(rect.size.width), ceilf(rect.size.height));
    if (labelSize.height <= CELL_MIN_HEIGHT)
        return CELL_MIN_HEIGHT;
    else
        return labelSize.height+2.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && [nonEditableItems count] > 0)
    {
        return [self getHeightForCellLabelTag:1 labelBaseHeight:LABEL_BASE_HEIGHT withString:[nonEditableItems objectAtIndex:indexPath.row]];
    }
    else if ((indexPath.section == 0 && [nonEditableItems count] == 0) || indexPath.section == 1)
    {
        if (indexPath.row == [editedItems count])
        {
            return CELL_MIN_HEIGHT;
        }
        else
        {
            return [self getHeightForCellLabelTag:1 labelBaseHeight:LABEL_BASE_HEIGHT withString:[editedItems objectAtIndex:indexPath.row]];

        }
    }
    else
        return CELL_MIN_HEIGHT;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
        return headerText;
    else
        return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if ((allowEditing && ((section == 0 && [nonEditableItems count] == 0) || section == 1)) ||
        (!allowEditing && section == 0))
    {
        return footerText;
    }
    else
        return nil;
}

- (void) handleNonEditingCellSelection:(NSIndexPath*)indexPath
{
    // Deselect old cell
    if (selectedItem >= 0)
    {
        NSIndexPath* oldIndexPath = nil;
        if ([nonEditableItems count] == 0 || selectedItem < [nonEditableItems count])
            oldIndexPath = [NSIndexPath indexPathForRow:selectedItem inSection:0];
        else
            oldIndexPath = [NSIndexPath indexPathForRow:(selectedItem-[nonEditableItems count]) inSection:1];
 
        UITableViewCell* oldCell = [self.tableView cellForRowAtIndexPath:oldIndexPath];	
        oldCell.accessoryType = UITableViewCellAccessoryNone;
    }

    // Update selected item
    selectedItem = (int)indexPath.row;
    NSString* selectedValue = nil;
    if (indexPath.section == 0)
    {
        if ([nonEditableItems count] == 0)
            selectedValue = [editableItems objectAtIndex:selectedItem];
        else
            selectedValue = [nonEditableItems objectAtIndex:selectedItem];
    }
    else if (indexPath.section == 1)
    {
        selectedValue = [editableItems objectAtIndex:selectedItem];
        selectedItem += [nonEditableItems count];
    }
    
    [self updateDoneButtonEnabled];
    
    // Select new cell & inform delegate
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    if (delegate && [delegate respondsToSelector:@selector(handleSelectItemInList:value:identifier:subIdentifier:)])
    {
        [delegate handleSelectItemInList:selectedItem value:selectedValue identifier:identifier subIdentifier:subIdentifier];
    }						   
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row

    if (isEditing)
    {
        if ((indexPath.section == 0 && [nonEditableItems count] == 0) || indexPath.section == 1)
        {
            if (indexPath.row == [editedItems count])
            {
                // Display text entry view for add item
                TextEntryViewController* textController = [[TextEntryViewController alloc]
                                                           initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TextEntryViewController"]
                                                           bundle:[DosecastUtil getResourceBundle]
                                                           viewTitle:addItemCellText
                                                           numTextFields:1
                                                           multiline:NO
                                                           initialValues:[NSArray arrayWithObject:@""]
                                                           placeholderStrings:[NSArray arrayWithObject:addItemPlaceholderText]
                                                           capitalizationType:UITextAutocapitalizationTypeWords
                                                           correctionType:UITextAutocorrectionTypeYes
                                                           keyboardType:UIKeyboardTypeDefault
                                                           secureTextEntry:NO
                                                           identifier:[NSString stringWithFormat:@"%d", (int)indexPath.row]
                                                           subIdentifier:nil
                                                           delegate:self];
                [self.navigationController pushViewController:textController animated:YES];
            }
            else
            {                
                // Display text entry view for existing item
                TextEntryViewController* textController = [[TextEntryViewController alloc]
                                                           initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TextEntryViewController"]
                                                           bundle:[DosecastUtil getResourceBundle]
                                                           viewTitle:viewTitle
                                                           numTextFields:1
                                                           multiline:NO
                                                           initialValues:[NSArray arrayWithObject:[editedItems objectAtIndex:indexPath.row]]
                                                           placeholderStrings:[NSArray arrayWithObject:addItemPlaceholderText]
                                                           capitalizationType:UITextAutocapitalizationTypeWords
                                                           correctionType:UITextAutocorrectionTypeYes
                                                           keyboardType:UIKeyboardTypeDefault
                                                           secureTextEntry:NO
                                                           identifier:[NSString stringWithFormat:@"%d", (int)indexPath.row]
                                                           subIdentifier:nil
                                                           delegate:self];
                [self.navigationController pushViewController:textController animated:YES];
            }
        }
    }
    else
    {
        if (indexPath.section == 0 && [nonEditableItems count] > 0)
        {
            [self handleNonEditingCellSelection:indexPath];
        }
        else if ((indexPath.section == 0 && [nonEditableItems count] == 0) || indexPath.section == 1)
        {
            if (indexPath.row == [editedItems count])
            {
                // Display text entry view for add item
                TextEntryViewController* textController = [[TextEntryViewController alloc]
                                                           initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TextEntryViewController"]
                                                           bundle:[DosecastUtil getResourceBundle]
                                                           viewTitle:addItemCellText
                                                           numTextFields:1
                                                           multiline:NO
                                                           initialValues:[NSArray arrayWithObject:@""]
                                                           placeholderStrings:[NSArray arrayWithObject:addItemPlaceholderText]
                                                           capitalizationType:UITextAutocapitalizationTypeWords
                                                           correctionType:UITextAutocorrectionTypeYes
                                                           keyboardType:UIKeyboardTypeDefault
                                                           secureTextEntry:NO
                                                           identifier:[NSString stringWithFormat:@"%d", (int)indexPath.row]
                                                           subIdentifier:nil
                                                           delegate:self];
                [self.navigationController pushViewController:textController animated:YES];
            }
            else
            {
                [self handleNonEditingCellSelection:indexPath];
            }
        }
     }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && [nonEditableItems count] > 0)
        return NO;
    else
        return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ((indexPath.section == 0 && [nonEditableItems count] == 0) || indexPath.section == 1)
    {
        if (indexPath.row == [editedItems count])
            return UITableViewCellEditingStyleInsert;
        else
            return UITableViewCellEditingStyleDelete;
    }
    else
        return UITableViewCellEditingStyleNone;        
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleInsert)
	{
        // Display text entry view for add item
        TextEntryViewController* textController = [[TextEntryViewController alloc]
                                                   initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TextEntryViewController"]
                                                   bundle:[DosecastUtil getResourceBundle]
                                                   viewTitle:addItemCellText
                                                   numTextFields:1
                                                   multiline:NO
                                                   initialValues:[NSArray arrayWithObject:@""]
                                                   placeholderStrings:[NSArray arrayWithObject:addItemPlaceholderText]
                                                   capitalizationType:UITextAutocapitalizationTypeWords
                                                   correctionType:UITextAutocorrectionTypeYes
                                                   keyboardType:UIKeyboardTypeDefault
                                                   secureTextEntry:NO
                                                   identifier:[NSString stringWithFormat:@"%d", (int)indexPath.row]
                                                   subIdentifier:nil
                                                   delegate:self];
        [self.navigationController pushViewController:textController animated:YES];
	}
	else if (editingStyle == UITableViewCellEditingStyleDelete)
	{        
        NSMutableArray* newDeletedItems = [NSMutableArray arrayWithArray:deletedItems];
        NSMutableArray* newRenamedItems = [NSMutableArray arrayWithArray:renamedItems];
        NSMutableArray* newCreatedItems = [NSMutableArray arrayWithArray:createdItems];
        
        PicklistEditedItem* newItem = nil;
                        
        // Check among already created items
        int foundPosition = -1;
        PicklistEditedItem* createdItem = [self findPicklistEditedItemWithIndex:(int)indexPath.row inList:newCreatedItems foundPosition:&foundPosition];
        if (createdItem)
        {
            [newCreatedItems removeObjectAtIndex:foundPosition];
            [self decrementIndexesForPicklistEditedItemsWithIndexGreaterThan:(int)indexPath.row inList:newCreatedItems];
            // No need to decrement indexes for renamedList - the created items always come after
        }
        else
        {
            // See if this row is already in the deleted items, and if so, adjust the index to find the next available one
            int deletedItemIndex = [self calculateDeletedItemsIndexForNewIndex:(int)indexPath.row inList:newDeletedItems];
            NSString* deletedValue = nil;
            if (deletedItemIndex < [editableItems count])
                deletedValue = [editableItems objectAtIndex:deletedItemIndex];
            
            // See if delegate wants to allow this deletion
            BOOL allowDeletion = YES;
            if (delegate && [delegate respondsToSelector:@selector(allowItemDeletion:value:identifier:subIdentifier:)])
            {
                allowDeletion = [delegate allowItemDeletion:deletedItemIndex value:deletedValue identifier:identifier subIdentifier:subIdentifier];
            }
            if (!allowDeletion)
                return;

            // Check among already renamed items
            PicklistEditedItem* renamedItem = [self findPicklistEditedItemWithIndex:(int)indexPath.row inList:newRenamedItems foundPosition:&foundPosition];
            if (renamedItem)
            {
                [newRenamedItems removeObjectAtIndex:foundPosition];
                [self decrementIndexesForPicklistEditedItemsWithIndexGreaterThan:(int)indexPath.row inList:newRenamedItems];
                [self decrementIndexesForPicklistEditedItemsWithIndexGreaterThan:(int)indexPath.row inList:newCreatedItems];
                                
                renamedItem.index = deletedItemIndex;
                newItem = renamedItem;
            }
            else
            {
                [self decrementIndexesForPicklistEditedItemsWithIndexGreaterThan:(int)indexPath.row inList:newRenamedItems];
                [self decrementIndexesForPicklistEditedItemsWithIndexGreaterThan:(int)indexPath.row inList:newCreatedItems];

                // Create a new deleted item
                newItem = [[PicklistEditedItem alloc] init:[editedItems objectAtIndex:indexPath.row] index:deletedItemIndex];
            }
        }
        
        if (newItem)
        {
            [newDeletedItems addObject:newItem];
            
            // Sort deleted items by index
            [newDeletedItems sortUsingFunction:comparePicklistEditedItems context:NULL];
        }
        
        // If we're editing, delete a row. The delegate will get notified when the user taps 'Done'
        if (isEditing)
        {
            [deletedItems setArray:newDeletedItems];
            [renamedItems setArray:newRenamedItems];
            [createdItems setArray:newCreatedItems];
            [self updateEditedItems];
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];  
        }
        else // If we're not editing, we just deleted an item - and therefore need to inform the delegate to get it committed
        {
            if (delegate && [delegate respondsToSelector:@selector(handleRequestEditItems:renamedItems:createdItems:identifier:subIdentifier:)])
            {
                [delegate handleRequestEditItems:newDeletedItems renamedItems:newRenamedItems createdItems:newCreatedItems identifier:identifier subIdentifier:subIdentifier];
            }
            else
            {
                [self commitEdits:newDeletedItems renamedItems:newRenamedItems createdItems:newCreatedItems];
            }
        }        
    }	
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}



@end

