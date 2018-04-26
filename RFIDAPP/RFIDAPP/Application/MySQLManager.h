//
//  MySQLManager.h
//  RFIDAPP
//
//  Created by lipeiyao on 2018/4/24.
//  Copyright © 2018年 Apple Developer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LabelModel.h"
typedef void(^Callback)(BOOL success);

typedef void(^Success)(BOOL success, NSString *errMsg);
typedef void(^Result)(BOOL exist, NSString *errMsg);
typedef void(^ResultList)(NSArray<LabelModel *> *list, NSString *errMsg);
//数据库管理类
@interface MySQLManager : NSObject

@property (nonatomic,readonly, assign) BOOL connected; ///< 是否已经连接到数据库



//单例
+ (instancetype)shareInstance;

//连接数据库
- (void)connetctMySQL;//同步连接方法
- (void)connetctMySQL:(Callback)callback;//异步连接方法

//插入数据,注：param的key必须和表中的key一致,否则会插入失败。
/*
    NSDictionary *param =@{@"real_name":@"李菲菲",
    @"mobile":@"13800138000",
    @"user_name":@"lifeifei",
    @"user_pwd":@"123456",
    @"user_school_id":@"52018812",
    @"label_code":@"a123"
    }
 */

/*******************************登录相关***************************************/

//检查登录
- (void)loginWithUserName:(NSString *)userName pwd:(NSString *)pwd callback:(Success)callback;
//检查用户名对应的手机号码是否存在
- (void )checkMobileExist:(NSString *)mobile userName:(NSString *)userName callback:(Result)callback;
//检查用户名是否存在
- (void)checkUserNameExist:(NSString *)userName callback:(Result)callback;
//获取短信验证码
- (void)getVerificationCode:(NSString *)mobile callback:(void(^)(NSString *code, NSString *errMsg))callback;
//重置密码
- (void)resetPassword:(NSString *)userName pwd:(NSString *)pwd callback:(Success)callback;

/*******************************标签相关***************************************/

//添加标签
- (void)addLabel:(NSString *)labelId userName:(NSString *)userName desc:(NSString *)desc callback:(Success)callback;
//检查标签是否已经存在
- (void)checkLabelExist:(NSString *)labelId userName:(NSString *)userName callback:(Result)callback;
//查询所有的标签
- (void)getAllLabels:(void(^)(NSArray <LabelModel *> *list, NSString *errMsg))callback;
//搜索标签
- (void)searchLabel:(NSString *)searchContent callback:(void(^)(NSArray <LabelModel *> *list, NSString *errMsg))callback;
//删除标签
- (void)deleteLabel:(NSString *)labelId userName:(NSString *)userName callback:(Success)callback ;

//认证标签
- (void)authLabel:(NSString *)labelId userName:(NSString *)userName callback:(ResultList)callback ;


@end
