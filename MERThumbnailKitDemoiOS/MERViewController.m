//
//  MERViewController.m
//  MERThumbnailKitDemoiOS
//
//  Created by William Towe on 5/1/14.
//  Copyright (c) 2014 Maestro, LLC. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "MERViewController.h"
#import <MERThumbnailKit/MERThumbnailKit.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <libextobjc/EXTScope.h>
#import <MEFoundation/MEFoundation.h>
#import <SVProgressHUD/SVProgressHUD.h>
#import <QuickLook/QuickLook.h>

@interface MERCollectionViewCell : UICollectionViewCell
@property (strong,nonatomic) UIImageView *imageView;
@end

@implementation MERCollectionViewCell

- (id)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame]))
        return nil;
    
    [self setImageView:[[UIImageView alloc] initWithFrame:CGRectZero]];
    [self.imageView setContentMode:UIViewContentModeScaleAspectFit];
    [self.imageView setClipsToBounds:YES];
    [self.contentView addSubview:self.imageView];
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.imageView setFrame:self.contentView.bounds];
}

@end

@interface MERViewController () <UICollectionViewDataSource,UICollectionViewDelegate,QLPreviewControllerDataSource,QLPreviewControllerDelegate>
@property (strong,nonatomic) UICollectionView *collectionView;

@property (copy,nonatomic) NSArray *urls;

@property (strong,nonatomic) id<QLPreviewItem> previewItem;
@end

@implementation MERViewController

- (id)init {
    if (!(self = [super init]))
        return nil;
    
    NSDirectoryEnumerator *directoryEnum = [[NSFileManager defaultManager] enumeratorAtURL:[[NSBundle mainBundle] URLForResource:@"Files" withExtension:nil] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants|NSDirectoryEnumerationSkipsPackageDescendants|NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *url, NSError *error) {
        MELogObject(error);
        return YES;
    }];
    
    NSMutableArray *urls = [[NSMutableArray alloc] init];
    
    for (NSString *urlString in [NSArray arrayWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"RemoteURLs" withExtension:@"plist"]])
        [urls addObject:[NSURL URLWithString:urlString]];
    
    [self setUrls:[urls arrayByAddingObjectsFromArray:directoryEnum.allObjects]];
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    
    [layout setMinimumInteritemSpacing:8];
    [layout setMinimumLineSpacing:8];
    [layout setItemSize:([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? CGSizeMake(150, 150) : CGSizeMake(100, 100)];
    [layout setSectionInset:UIEdgeInsetsMake(8, 8, 8, 8)];
    
    [self setCollectionView:[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout]];
    [self.collectionView setBackgroundColor:[UIColor whiteColor]];
    [self.collectionView registerClass:[MERCollectionViewCell class] forCellWithReuseIdentifier:NSStringFromClass([MERCollectionViewCell class])];
    [self.collectionView setDataSource:self];
    [self.collectionView setDelegate:self];
    [self.view addSubview:self.collectionView];
}
- (void)viewDidLayoutSubviews {
    [self.collectionView setFrame:self.view.bounds];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.urls.count;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MERCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([MERCollectionViewCell class]) forIndexPath:indexPath];
    
    @weakify(cell);
    
    [[[[[MERThumbnailManager sharedManager]
       thumbnailForURL:self.urls[indexPath.row]]
      takeUntil:[cell rac_prepareForReuseSignal]]
      deliverOn:[RACScheduler mainThreadScheduler]]
     subscribeNext:^(RACTuple *value) {
         @strongify(cell);
         
         RACTupleUnpack(__unused NSURL *url, UIImage *image, NSNumber *cacheType) = value;
        
         MELog(@"%@ %@",url,cacheType);
         
         [cell.imageView setImage:image];
    }];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSURL *url = self.urls[indexPath.row];
    
    if (!url.isFileURL) {
        @weakify(self);
        
        [[[[[[MERThumbnailManager sharedManager] downloadFileWithURL:self.urls[indexPath.row] progress:^(NSURL *url, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            [SVProgressHUD showProgress:(CGFloat)totalBytesWritten / (CGFloat)totalBytesExpectedToWrite];
        }] deliverOn:[RACScheduler mainThreadScheduler]] initially:^{
            [SVProgressHUD show];
        }] finally:^{
            [SVProgressHUD dismiss];
        }] subscribeNext:^(RACTuple *value) {
            @strongify(self);
            
            RACTupleUnpack(NSURL *url, NSURL *fileURL, NSNumber *cacheType) = value;
            
            MELog(@"%@ %@ %@",url,fileURL,cacheType);
            
            [self setPreviewItem:fileURL];
            
            QLPreviewController *viewController = [[QLPreviewController alloc] init];
            
            [viewController setDataSource:self];
            [viewController setDelegate:self];
            
            [self presentViewController:viewController animated:YES completion:nil];
        } error:^(NSError *error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Error code %@",@(error.code)] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
            
            [alertView show];
        }];
    }
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return (self.previewItem) ? 1 : 0;
}
- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return self.previewItem;
}

- (void)previewControllerDidDismiss:(QLPreviewController *)controller {
    [self setPreviewItem:nil];
}

@end
