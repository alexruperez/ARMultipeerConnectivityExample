//
//  ARViewController.m
//  MultipeerConnectivityExample
//
//  Created by alexruperez on 09/02/14.
//  Copyright (c) 2014 alexruperez. All rights reserved.
//

#import "ARViewController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface ARViewController () <MCSessionDelegate, MCAdvertiserAssistantDelegate, MCBrowserViewControllerDelegate, UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate, UIAlertViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (strong, nonatomic) MCSession *session;
@property (strong, nonatomic) MCAdvertiserAssistant *advertiserAssistant;
@property (strong, nonatomic) MCBrowserViewController *browserViewController;

@property (strong, nonatomic) NSArray *peers;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIButton *broadcastButton;

@end

@implementation ARViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    NSString *serviceType = @"ar-mc-example";
    
    self.session = [[MCSession alloc] initWithPeer:[[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]]];
    [self.session setDelegate:self];
    
    self.advertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:serviceType discoveryInfo:nil session:self.session];
    [self.advertiserAssistant setDelegate:self];
    [self.advertiserAssistant start];
    
    self.browserViewController = [[MCBrowserViewController alloc] initWithServiceType:serviceType session:self.session];
    [self.browserViewController setDelegate:self];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController
{
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController
{
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.broadcastButton setEnabled:[self.session.connectedPeers count]];
        [self.tableView reloadData];
    });
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.browserViewController dismissViewControllerAnimated:NO completion:nil];
    });
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    if (!error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.browserViewController dismissViewControllerAnimated:NO completion:nil];
        });
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.session.connectedPeers count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @"Connected Peers";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    MCPeerID *peer = self.session.connectedPeers[indexPath.row];
    [cell.textLabel setText:peer.displayName];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MCPeerID *peer = self.session.connectedPeers[indexPath.row];
    self.peers = @[peer];
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:peer.displayName delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Text", @"Image", @"Audio", nil];
    [actionSheet showInView:self.tableView];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex)
    {
        [self sendText:[alertView textFieldAtIndex:0].text];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self sendImage:info[UIImagePickerControllerOriginalImage]];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0:
            [self sendTextForm];
            break;
        case 1:
            [self performSelector:@selector(sendImageForm) withObject:nil afterDelay:0.3f];
            break;
        case 2:
            [self sendAudioForm];
            break;
        default:
            break;
    }
}

- (void)sendTextForm
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Text" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Send", nil];
    [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [alertView show];
}

- (void)sendImageForm
{
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    [imagePickerController setSourceType:UIImagePickerControllerSourceTypeCamera];
    [imagePickerController setDelegate:self];
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

- (void)sendAudioForm
{
    [self sendAudio:nil];
}

- (void)sendText:(NSString *)text
{
    if (text)
    {
        NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;
        if (![self.session sendData:data toPeers:self.peers withMode:MCSessionSendDataReliable error:&error]) {
            NSLog(@"%@", error.localizedDescription);
        }
    }
}

- (void)sendImage:(UIImage *)image
{
    if (image)
    {
        NSData *data = UIImagePNGRepresentation(image);
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = [paths objectAtIndex:0];
        NSString *filePath = [documentsPath stringByAppendingPathComponent:@"image.png"];
        [data writeToFile:filePath atomically:YES];
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        for (MCPeerID *peer in self.peers)
        {
            [self.session sendResourceAtURL:fileURL withName:[fileURL lastPathComponent] toPeer:peer withCompletionHandler:^(NSError *error) {
                if (error)
                {
                    NSLog(@"%@", error.localizedDescription);
                }
            }];
        }
    }
}

- (void)sendAudio:(NSURL *)fileURL
{
    if (fileURL)
    {
        for (MCPeerID *peer in self.peers)
        {
            [self.session sendResourceAtURL:fileURL withName:[fileURL lastPathComponent] toPeer:peer withCompletionHandler:^(NSError *error) {
                if (error)
                {
                    NSLog(@"%@", error.localizedDescription);
                }
            }];
        }
    }
}

- (IBAction)presentBrowser
{
    [self presentViewController:self.browserViewController animated:YES completion:nil];
}

- (IBAction)sendBroadcast
{
    self.peers = self.session.connectedPeers;
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Send Broadcast" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Text", @"Image", @"Audio", nil];
    [actionSheet showInView:self.view];
}

@end
