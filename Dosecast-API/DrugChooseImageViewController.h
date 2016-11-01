//
//  DrugChooseImageViewController.h
//  Dosecast-API
//
//  Created by David Sklenar on 9/24/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

/*
 * View controller to select and edit a drug image, using either the
 * camera (if available) or user's photo library.
 * 
 */

#import <UIKit/UIKit.h>

typedef enum {
	DrugImageSourceCamera	= 0,
	DrugImageSourcePhotoLibrary	= 1
} DrugImageSource;

@protocol DrugChooseImageDelegate;

@interface DrugChooseImageViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate>
{
@private
}

@property (strong, nonatomic) IBOutlet UIToolbar *toolbar;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *cancelBarButtonItem;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *cameraBarButtonItem;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *libraryBarButtonItem;
@property (strong, nonatomic) IBOutlet UIImageView *drugImageView;
@property (strong, nonatomic) IBOutlet UIButton *flashButton;
@property (strong, nonatomic) UIPopoverController *sharedPopover;
@property (strong, nonatomic) UIImagePickerController *picker;

@property (nonatomic, weak) id <DrugChooseImageDelegate> delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil image:(UIImage *)img delegate:(id <DrugChooseImageDelegate>)delegate;

- (IBAction)cancel:(id)sender;
- (IBAction)camera:(id)sender;
- (IBAction)library:(id)sender;
- (IBAction)flash:(id)sender;

@end


/*
 * Delegate to return the selected Medication object.
 */

@protocol DrugChooseImageDelegate <NSObject>
@optional
- (void)didCancelImageSelection;
- (void)didSelectImage:(UIImage *)img source:(DrugImageSource)source;
- (void)didChooseModalPhotoLibraryFromCameraUI;

@end






