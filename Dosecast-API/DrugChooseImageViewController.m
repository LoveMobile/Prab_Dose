//
//  DrugChooseImageViewController.m
//  Dosecast-API
//
//  Created by David Sklenar on 9/24/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "DrugChooseImageViewController.h"
#import "DosecastUtil.h"
#import <QuartzCore/QuartzCore.h>
#import "UIImage+Resize.h"
#import "DrugImagePickerController.h"

// The different UI sections & rows
typedef enum {
	DrugChooseImageViewControllerFlashStateOff  = 0,
	DrugChooseImageViewControllerFlashStateAuto = 1,
    DrugChooseImageViewControllerFlashStateOn   = 2
} DrugChooseImageViewControllerFlashState;

static int g_flashState = (int)DrugChooseImageViewControllerFlashStateOff;

@interface DrugChooseImageViewController ()

@end

@implementation DrugChooseImageViewController

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}


#pragma mark - Properties

@synthesize toolbar = _toolbar;
@synthesize cancelBarButtonItem = _cancelBarButtonItem;
@synthesize cameraBarButtonItem = _cameraBarButtonItem;
@synthesize libraryBarButtonItem = _libraryBarButtonItem;
@synthesize drugImageView = _drugImageView;
@synthesize sharedPopover = _sharedPopover;
@synthesize picker = _picker;
@synthesize flashButton = _flashButton;

@synthesize delegate = _delegate;


#pragma mark - API

- (IBAction)cancel:(id)sender
{
    if ([DosecastUtil isIPad])
    {
        if ( self.sharedPopover && [self.sharedPopover isPopoverVisible] )
            [self.sharedPopover dismissPopoverAnimated:YES];
    }
    
    if ( self.delegate && [self.delegate respondsToSelector:@selector(didCancelImageSelection)] )
        [self.delegate didCancelImageSelection];
}

- (IBAction)camera:(id)sender
{
    if (self.picker)
        [self.picker takePicture];
}

- (IBAction)library:(id)sender
{
    // Present the saved photos library UI. On the iPad, we must use a 
    // UIPopoverController to do so. On the iPhone/iPod, we can present 
    // the photos array modally.
        
    BOOL isiPadDevice = [DosecastUtil isIPad];
    
    // Displaying the library is device-specific.
    
    if ( isiPadDevice) 
    {
        // If the library popover is visible, do not display it again.
        
        if ( self.sharedPopover && [self.sharedPopover isPopoverVisible] )
        {
            [self.sharedPopover dismissPopoverAnimated:YES];
            return;
        }
        
        DrugImagePickerController *cameraUI = [[DrugImagePickerController alloc] init];
        
        cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        cameraUI.allowsEditing = YES;
        cameraUI.delegate = self;

        UIBarButtonItem *senderButton = (UIBarButtonItem *)sender;
        
        self.sharedPopover = [[UIPopoverController alloc] initWithContentViewController:cameraUI];
        [self.sharedPopover presentPopoverFromBarButtonItem:senderButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];        
    }
    else
    {
        if ( self.delegate && [self.delegate respondsToSelector:@selector(didChooseModalPhotoLibraryFromCameraUI)] )
            [self.delegate didChooseModalPhotoLibraryFromCameraUI];
    }
}

- (void) updateFlashButtonTitleAndSetting
{
    if (g_flashState == (int)DrugChooseImageViewControllerFlashStateOff)
    {
        [self.flashButton setTitle:NSLocalizedStringWithDefaultValue(@"ChooseImageFlashButtonOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Flash: Off", @"The title for the flash button when choosing a drug image") forState:UIControlStateNormal];
        if (self.picker)
            self.picker.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
    }
    else if (g_flashState == (int)DrugChooseImageViewControllerFlashStateAuto)
    {
        [self.flashButton setTitle:NSLocalizedStringWithDefaultValue(@"ChooseImageFlashButtonAuto", @"Dosecast", [DosecastUtil getResourceBundle], @"Flash: Auto", @"The title for the flash button when choosing a drug image") forState:UIControlStateNormal];
        if (self.picker)
            self.picker.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
    }
    else if (g_flashState == (int)DrugChooseImageViewControllerFlashStateOn)
    {
        [self.flashButton setTitle:NSLocalizedStringWithDefaultValue(@"ChooseImageFlashButtonOn", @"Dosecast", [DosecastUtil getResourceBundle], @"Flash: On", @"The title for the flash button when choosing a drug image") forState:UIControlStateNormal];
        if (self.picker)
            self.picker.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
    }
}

- (IBAction)flash:(id)sender
{
    g_flashState = (g_flashState+1) % 3;
    [self updateFlashButtonTitleAndSetting];
}

#pragma mark -  UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    // Dismiss the iPad popover, if it is visible.
    if ([DosecastUtil isIPad])
    {
        if ( self.sharedPopover && [self.sharedPopover isPopoverVisible] )
            [self.sharedPopover dismissPopoverAnimated:YES];
    }
    
    DrugImageSource source = [info valueForKey:UIImagePickerControllerEditedImage] ? DrugImageSourcePhotoLibrary : DrugImageSourceCamera;
    
    UIImage *pickedImage;
    
    // Get the edited (scaled and cropped) image from the picker delegate.
    
    if ( source == DrugImageSourcePhotoLibrary )
        pickedImage = (UIImage *)[info valueForKey:UIImagePickerControllerEditedImage];
    else        
        pickedImage = (UIImage *)[info valueForKey:UIImagePickerControllerOriginalImage];
    
    UIImage* resultImage = nil;
    
    if (source == DrugImageSourcePhotoLibrary)
    {
        resultImage = pickedImage;
    }
    else
    {
        UIImage *ignoreRotationImage = [[UIImage alloc] initWithCGImage:pickedImage.CGImage scale:1.0f orientation:UIImageOrientationUp];
        
        CGSize imageSize = CGSizeMake(ignoreRotationImage.size.height, ignoreRotationImage.size.width);
        CGSize frameSize = self.drugImageView.frame.size;
        CGSize viewSize = self.view.frame.size;
        
        double percentWidth = frameSize.width / viewSize.width;
        
        CGFloat pixelSide = percentWidth * imageSize.width;
        CGFloat yInset = (self.drugImageView.frame.origin.x / viewSize.width) * imageSize.width;
        double viewHeightCropped = (imageSize.height / imageSize.width) * viewSize.width;
        CGFloat xInset = (self.drugImageView.frame.origin.y / viewHeightCropped) * imageSize.height;
        
        CGRect cropRect = CGRectMake( xInset, yInset, pixelSide, pixelSide );
        
        UIImage* croppedImage = [ignoreRotationImage croppedImage:cropRect];
        resultImage = [[UIImage alloc] initWithCGImage:croppedImage.CGImage scale:1.0f orientation:pickedImage.imageOrientation];
    }
    
    // Notify the delegate of our image selection and source.
    if ( self.delegate && [self.delegate respondsToSelector:@selector(didSelectImage:source:)] )
        [self.delegate didSelectImage:resultImage source:source];
}


#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    popoverController = nil;
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    return YES;
}


#pragma mark - View Lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil image:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil image:(UIImage *)img delegate:(id <DrugChooseImageDelegate>)delegate
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if ( self )
    {
        _delegate = delegate;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Only enable the camera button for devices that support it.
    
    self.cameraBarButtonItem.enabled = ( [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] );
    
    self.cancelBarButtonItem.title = NSLocalizedStringWithDefaultValue( @"ChooseImageCancelButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The default button title for the cancel button when choosing a drug image" );
    self.libraryBarButtonItem.title = NSLocalizedStringWithDefaultValue( @"ChooseImageLibraryButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Library", @"The default button title for the library button when choosing a drug image" );
    
    self.navigationController.navigationBar.barTintColor = [DosecastUtil getNavigationBarColor];
    self.navigationController.toolbar.barTintColor = [DosecastUtil getToolbarColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.toolbar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
    self.toolbar.barTintColor = [DosecastUtil getToolbarColor];
    self.toolbar.tintColor = [UIColor whiteColor];
    
    self.drugImageView.layer.borderColor = [[UIColor whiteColor] CGColor];
    self.drugImageView.layer.borderWidth = 2.0f;
    self.drugImageView.layer.cornerRadius = 3.0f;
        
    self.flashButton.hidden = ![UIImagePickerController isFlashAvailableForCameraDevice:UIImagePickerControllerCameraDeviceRear] || ![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    if (!self.flashButton.hidden)
    {
        [self updateFlashButtonTitleAndSetting];
        [DosecastUtil setBackgroundColorForButton:self.flashButton color:[DosecastUtil getToolbarColor]];
        self.flashButton.alpha = 0.5f;
    }
}

@end
