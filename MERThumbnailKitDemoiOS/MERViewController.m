//
//  MERViewController.m
//  MERThumbnailKitDemoiOS
//
//  Created by William Towe on 5/1/14.
//  Copyright (c) 2014 Maestro, LLC. All rights reserved.
//

#import "MERViewController.h"
#import <MERThumbnailKit/MERThumbnailKit.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <libextobjc/EXTScope.h>
#import <MEFoundation/MEFoundation.h>

@interface MERCollectionViewCell : UICollectionViewCell
@property (strong,nonatomic) UIImageView *imageView;
@end

@implementation MERCollectionViewCell

- (id)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame]))
        return nil;
    
    [self setImageView:[[UIImageView alloc] initWithFrame:CGRectZero]];
    [self.imageView setContentMode:UIViewContentModeScaleAspectFill];
    [self.imageView setClipsToBounds:YES];
    [self.contentView addSubview:self.imageView];
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.imageView setFrame:self.contentView.bounds];
}

@end

@interface MERViewController () <UICollectionViewDataSource,UICollectionViewDelegate>
@property (strong,nonatomic) UICollectionView *collectionView;

@property (copy,nonatomic) NSArray *urls;
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
    [layout setItemSize:CGSizeMake(100, 100)];
    [layout setSectionInset:UIEdgeInsetsMake(8, 8, 8, 8)];
    
    [self setCollectionView:[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout]];
    [self.collectionView setBackgroundColor:[UIColor whiteColor]];
    [self.collectionView registerClass:[MERCollectionViewCell class] forCellWithReuseIdentifier:NSStringFromClass([MERCollectionViewCell class])];
    [self.collectionView setDataSource:self];
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
         
         RACTupleUnpack(NSURL *url, UIImage *image, NSNumber *cacheType) = value;
         
         MELog(@"%@ %@",url,cacheType);
         
         [cell.imageView setImage:image];
    }];
    
    return cell;
}

@end
