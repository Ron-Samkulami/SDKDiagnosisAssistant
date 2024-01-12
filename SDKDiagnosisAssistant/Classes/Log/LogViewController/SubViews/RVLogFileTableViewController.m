//
//  RVLogFileTableViewController.m
//
//  Created by 石学谦 on 2020/1/2.
//  Copyright © 2020 shixueqian. All rights reserved.
//

#import "RVLogFileTableViewController.h"
#import "RVOnlyLog.h"

@interface RVLogFileTableViewController ()<UIDocumentInteractionControllerDelegate>

@property (nonatomic,strong)NSMutableArray *fileNames;//文件名

@property (nonatomic, strong)UIBarButtonItem *editItem;//编辑-完成
@property (nonatomic, strong)UIBarButtonItem *allSelectedBtn;//全选-取消全选
@property (nonatomic, strong)UIBarButtonItem *deleteItem;//删除

@end

@implementation RVLogFileTableViewController


#pragma mark - 生命周期方法

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSMutableArray *reverseFileNames = [NSMutableArray array];
    _fileNames = [NSMutableArray array];
    //有删除操作，从后台往前遍历
    for (int i=(int)_filePaths.count-1; i>=0; i--) {
        NSLogDebug(@"_filePaths i=%d",i);
        NSString *filePath = _filePaths[i];
        BOOL isExist = [fileMgr fileExistsAtPath:filePath];
        if (!isExist) {
            //对不存在的文件路径进行过滤
            [_filePaths removeObjectAtIndex:i];
            continue;
        }
        NSString *fileName = [filePath lastPathComponent];
        
        //显示文件大小
        NSString *fileSizeStr = [self getFileSizeStrWithPath:filePath];
    
        fileName = [fileName stringByAppendingFormat:@"(%@)",fileSizeStr];
        [reverseFileNames addObject:fileName];
    }
    //顺序重新翻转
    for (int i=(int)reverseFileNames.count-1; i>=0; i--) {
        NSString *fileName = reverseFileNames[i];
        [_fileNames addObject:fileName];
    }
    
    _editItem = [[UIBarButtonItem alloc] initWithTitle:@"编辑" style:(UIBarButtonItemStylePlain) target:self action:@selector(editBtn:)];
    _allSelectedBtn = [[UIBarButtonItem alloc] initWithTitle:@"全选" style:(UIBarButtonItemStylePlain) target:self action:@selector(selectAllBtn:)];
    _deleteItem = [[UIBarButtonItem alloc] initWithTitle:@"删除" style:(UIBarButtonItemStylePlain) target:self action:@selector(deleteBtn:)];
    _deleteItem.tintColor = [UIColor redColor];

    [self.navigationItem setRightBarButtonItems:@[_editItem]];
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    //本控制器显示bar
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //恢复之前不显示的设置
     self.navigationController.navigationBar.hidden = YES;
}

#pragma mark - barItem点击操作

- (void)editBtn:(UIBarButtonItem *)item {
    if ([_editItem.title isEqualToString:@"编辑"]) {
        self.tableView.editing = YES;
        _editItem.title = @"完成";
        _allSelectedBtn.title = @"全选";
        [self.navigationItem setRightBarButtonItems:@[_editItem,_allSelectedBtn,_deleteItem]];
        
    } else {
        //删除
        [self.navigationItem setRightBarButtonItems:@[_editItem]];
        _editItem.title = @"编辑";
        self.tableView.editing = NO;
    }
}
- (void)selectAllBtn:(UIBarButtonItem *)item {
    
    if ([_allSelectedBtn.title isEqualToString:@"全选"]) {
        _allSelectedBtn.title = @"取消";
        
        for (int i=0; i<self.fileNames.count; i++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:(UITableViewScrollPositionTop)];
        }
        
    } else {
        _allSelectedBtn.title = @"全选";
        
        for (int i=0; i<self.fileNames.count; i++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
        }
    }
}

- (void)deleteBtn:(UIBarButtonItem *)item {
    
    for (int i=(int)self.fileNames.count-1; i>=0; i--) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        NSLogRVSDK(@"cell.selected=%d",cell.selected);
        if (cell.selected) {
            [self deleteFileWithIndexPath:indexPath];
        }
    }
    
}

- (void)deleteFileWithIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger index = indexPath.row;
    if (_fileNames.count-1 < index) {
        return;
    }
    NSString *filePath = _filePaths[index];
    BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    if (!isExist) {
        return;
    }
    [_fileNames removeObjectAtIndex:index];
    [_filePaths removeObjectAtIndex:index];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    return _fileNames.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //如果使用这个方法获取cell，必须要先register一个cell
//    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RVLogFileTableViewController" forIndexPath:indexPath];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RVLogFileTableViewController"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:(UITableViewCellStyleValue1) reuseIdentifier:@"RVLogFileTableViewController"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSInteger row = indexPath.row;
    cell.textLabel.text = _fileNames[row];
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
//    UITableViewRowAction *action1 = [UITableViewRowAction rowActionWithStyle:(UITableViewRowActionStyleNormal) title:@"第一个" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        //什么都不做，恢复原样
//        [tableView setEditing:NO animated:YES];
//    }];
    
    UITableViewRowAction *actin2 = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"删除" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        
         //删除一行
        [self deleteFileWithIndexPath:indexPath];
    }];
    return @[actin2];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.tableView.editing) {
        return;
    }
    NSString *filePath = _filePaths[indexPath.row];
    [self displayLocalLogWithFilePath:filePath];
}

#pragma mark - log显示操作

//显示沙盒本地log（在iOS13模拟器会报错，真机不会，这是一个苹果的bug）
- (void)displayLocalLogWithFilePath:(NSString *)filePath
{
    //由文件路径初始化UIDocumentInteractionController
    UIDocumentInteractionController *documentInteractionController  = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:filePath]];
    //设置代理
    documentInteractionController .delegate = self;
    //显示预览界面
    [documentInteractionController  presentPreviewAnimated:YES];
}

#pragma mark - UIDocumentInteractionControllerDelegate
//在哪个控制器显示预览界面
-(UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller
{
    return self;
}

//MARK: - self getFileSizeStrWithPath 公用方法上浮
//根据传入的文件路径返回显示的字符串 xxB,xxK,,xxM,xxG
- (NSString *)getFileSizeStrWithPath:(NSString *)path {
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    BOOL isDir = NO;
    NSString *fileSizeStr = @"0B";
    if(![fileMgr fileExistsAtPath:path isDirectory:&isDir]) {
        return fileSizeStr;
    }
    
    unsigned long long fileSize = 0;
    if (!isDir) {
        //显示文件大小
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        fileSize = attr.fileSize;
    } else {
        //我们只算一层的
        NSArray *subPaths =  [fileMgr subpathsAtPath:path];
        if (subPaths && subPaths.count > 0) {
            for (int i=0; i<subPaths.count; i++) {
                NSString *subPath = [path stringByAppendingPathComponent:subPaths[i]];
                NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:subPath error:nil];
                fileSize += attr.fileSize;
            }
        }
    }
    
    if (fileSize <= 0) {
        return fileSizeStr;
    }
    
    CGFloat unitSize = 1000.0f;
    
    if (fileSize < unitSize) {
        fileSizeStr = [NSString stringWithFormat:@"%lldB",fileSize];
    } else if (fileSize < unitSize*unitSize) {
        fileSizeStr = [NSString stringWithFormat:@"%fKB",fileSize/unitSize];
    } else if (fileSize < unitSize*unitSize*unitSize) {
        fileSizeStr = [NSString stringWithFormat:@"%.2fMB",fileSize/unitSize/unitSize];
    } else {
        fileSizeStr = [NSString stringWithFormat:@"%.2fGB",fileSize/unitSize/unitSize/unitSize];
    }
    return fileSizeStr;
}
@end
