//
//  MySQLManager.m
//  RFIDAPP
//
//  Created by fenglh on 2018/4/24.
//  Copyright © 2018年 Apple Developer. All rights reserved.
//

#import "MySQLManager.h"
#import "mysql.h"
#import "UserModel.h"

#import "VerificationCodeModel.h"
#define CONNECTION_HOST                 "rm-bp162p7vebc90r3q5co.mysql.rds.aliyuncs.com"
#define CONNECTION_USER                 "root"
#define CONNECTION_PASS                 "Hmily418"
#define CONNECTION_DB                   "pydatabase"
#define TABLE_USERS                     @"table_users"
#define TABLE_VERIFICATION_CODE         @"table_verification_code"
#define TABLE_LABELS                    @"table_labels"



@interface MySQLManager ()
@property (nonatomic) MYSQL *sock;    //连接远程数据库
@property (nonatomic, copy) NSArray *tables; //数据库表数据
@property (nonatomic,readwrite, assign) BOOL connected; ///< 是否已经连接到数据库

@end

@implementation MySQLManager
//单例
+ (instancetype)shareInstance {
    static MySQLManager *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[[self class] alloc] init];
        instance.connected = NO;
    });
    return instance;
}



#pragma mark - 公有方法

//忘记密码-匹配账号和手机号码
- (void)checkUserNameExist:(NSString *)userName callback:(Success)callback {
    NSString *sql = [NSString stringWithFormat:@"SELECT * from %@ WHERE user_name='%@';", TABLE_USERS, userName];
    
    [self queryFromUserTable:sql callback:^(NSArray<UserModel *> *list, NSString *errMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(list.count, errMsg):nil;
        });
        
    }];

}

- (void )checkMobileExist:(NSString *)mobile userName:(NSString *)userName callback:(Success)callback {
    NSString *sql = [NSString stringWithFormat:@"SELECT * from %@ WHERE user_name='%@' and mobile='%@'", TABLE_USERS, userName, mobile];
    [self queryFromUserTable:sql callback:^(NSArray<UserModel *> *list, NSString *errMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(list.count, errMsg):nil;
        });
        
    }];
}


//登录
- (void)checkLoginWithUserName:(NSString *)userName pwd:(NSString *)pwd callback:(Success)callback {
    NSString *sql = [NSString stringWithFormat:@"SELECT * from %@ WHERE user_name='%@' and user_pwd='%@'", TABLE_USERS, userName, pwd];
    [self queryFromUserTable:sql callback:^(NSArray<UserModel *> *list, NSString *errMsg) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(list.count, errMsg):nil;//非0即真，当arr.cout != 0 时即为YES
        });
    }];

}

//重置密码-获取验证码
- (void)getVerificationCode:(NSString *)mobile callback:(void(^)(NSString *code, NSString *errMsg))callback {
    NSString *sql = [NSString stringWithFormat:@"SELECT * from %@ WHERE mobile='%@' ", TABLE_VERIFICATION_CODE, mobile];
    [self queryFromVerificationCodeTable:sql callback:^(NSArray<VerificationCodeModel *> *list, NSString *errMsg) {
        NSString *code = nil;
        if (list.count) {
            VerificationCodeModel *model = [list firstObject];
            code = model.code;
            //模拟验证码发送，延时2秒
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //因为没有接入短信系统，所以这里使用顶部提示来模拟接收到短信
                [TopToast showToptoastWithText:[NSString stringWithFormat:@"获取到短信验证码:%@", code] duration:3.f ];
            });
            
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(code, errMsg):nil;//非0即真，当arr.cout != 0 时即为YES
        });
        
    }];

}

//重置密码-重置
- (void)resetPassword:(NSString *)userName pwd:(NSString *)pwd callback:(Success)callback {
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ set user_pwd='%@' WHERE user_name='%@' ", TABLE_USERS, pwd, userName];
    [self updateFromUserTable:sql callback:^(BOOL success, NSString *errMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(success, errMsg):nil;//非0即真，当arr.cout != 0 时即为YES
        });
    }];
}

//检查标签是否已经存在
- (void)checkLabelExist:(NSString *)labelId userName:(NSString *)userName callback:(Success)callback {
    NSString *sql = [NSString stringWithFormat:@"SELECT * from %@ WHERE label_user='%@' and label_code='%@'", TABLE_LABELS, userName, labelId];
    @weakify(self);
    [self query:sql callback:^(MYSQL_RES *result, NSString *errorMsg) {
        @strongify(self);
        NSMutableArray *list = [NSMutableArray array];
        if (result) {
            //遍历每一行记录
            MYSQL_ROW row;
            while ((row = mysql_fetch_row(result))) {
                LabelModel *model = [[LabelModel alloc] init];
                //如果表中新增字段，那么这里的索引顺序应当改变
                model.labelUser = [self decodeCString:row[1]];
                model.labelId = [self decodeCString:row[2]];
                model.LabelDesc = [self decodeCString:row[3]];
                [list addObject:model];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(!list.count, errorMsg):nil;//非0即真，当arr.cout != 0 时即为YES
        });
        
    }];

}

//添加标签
- (void)addLabel:(NSString *)labelId userName:(NSString *)userName desc:(NSString *)desc callback:(Success)callback {
    if (userName == nil || labelId == nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(NO, @"用户名或标签码不能为空"):nil;
        });
        return ;
    }
    if (desc == nil) {
        desc = @"";
    }
    NSMutableDictionary *param = [NSMutableDictionary dictionary];
    [param setObject:userName forKey:@"label_user"];
    [param setObject:labelId forKey:@"label_code"];
    [param setObject:desc forKey:@"label_desc"];
    
    [self insert:param table:TABLE_LABELS callback:^(BOOL success, NSString *errMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(success, errMsg):nil;
        });
    }];
}

- (void)getAllLabels:(void(^)(NSArray <LabelModel *> *list, NSString *errMsg))callback{
    NSString *sql = [NSString stringWithFormat:@"SELECT * from %@ ", TABLE_LABELS];
    [self queryFromLabelsTable:sql callback:^(NSArray<LabelModel *> *list, NSString *errMsg) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(list, errMsg):nil;
        });
    }];
}

- (void)searchLabel:(NSString *)searchContent callback:(void(^)(NSArray <LabelModel *> *list, NSString *errMsg))callback {
    NSString *sql = [NSString stringWithFormat:@"SELECT * from %@ WHERE label_user like '%%%@%%' or label_code like'%%%@%%' ;", TABLE_LABELS,searchContent, searchContent];
    [self queryFromLabelsTable:sql callback:^(NSArray<LabelModel *> *list, NSString *errMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(list, errMsg):nil;
        });
    }];
}

- (void)deleteLabel:(NSString *)labelId userName:(NSString *)userName callback:(Success)callback {
    NSString *sql = [NSString stringWithFormat:@"DELETE  from %@ WHERE label_user='%@' and label_code='%@' ;", TABLE_LABELS,userName, labelId];
    return [self delete:sql callback:^(BOOL success, NSString *errMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback?callback(success, errMsg):nil;
        });
    }];
}

#pragma mark - 私有方法
- (NSString *)decodeCString:(const char *)charData {
    return [[NSString alloc] initWithCString:charData encoding:NSUTF8StringEncoding];
}

#pragma mark - 数据库操作
//连接数据库-同步
- (void)connetctMySQL{
    self.sock = mysql_init(NULL);
    mysql_options(self.sock, MYSQL_SET_CHARSET_NAME, "utf8");
    MYSQL *connection = mysql_real_connect(self.sock, CONNECTION_HOST, CONNECTION_USER, CONNECTION_PASS, CONNECTION_DB, 3306, NULL, 0);
    if (connection) {
        self.connected = YES;
        NSLog(@"连接到数据库成功!");
    } else {
        self.connected = NO;
        NSLog(@"连接到数据库失败!");
    }
}



//连接数据库-异步
- (void)connetctMySQL:(Callback)callback {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.sock = mysql_init(NULL);
        mysql_options(self.sock, MYSQL_SET_CHARSET_NAME, "utf8");
        MYSQL *connection = mysql_real_connect(self.sock, CONNECTION_HOST, CONNECTION_USER, CONNECTION_PASS, CONNECTION_DB, 3306, NULL, 0);
        if (connection) {
            self.connected = YES;
            //主线程操作UI
            if (callback) {
                callback(YES);
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^ {
                [BMShowHUD showError:@"连接远程数据库失败!"];
            });
            if (callback) {
                self.connected = NO;
                callback(NO);
            }
        }
    });
}

- (void)closeMySQL {
    if (self.sock) {
        //关闭数据库连接
        mysql_close(self.sock);
    }
}


//插入数据库
- (void )insert:(NSDictionary *)param table:(NSString *)table callback:(Success)callback

{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString *insertNames=@"";
        NSString *insertValues=@"";
        
        NSArray *allKeys = [param allKeys];
        for (NSString *key in allKeys) {
            //拼接names ，例如：(`real_name`,`user_name`, `user_pwd`, `user_school_id`, `label_code`)
            insertNames=[insertNames stringByAppendingString:[NSString stringWithFormat:@"`%@`,", key]];
            //拼接valus，例如：('ff', '李三', '888888', '9999','hjk345678')
            insertValues=[insertValues stringByAppendingString:[NSString stringWithFormat:@"'%@',", [param objectForKey:key]]];
        }
        
        if (insertNames && insertValues) {
            insertNames = [insertNames substringToIndex:insertNames.length - 1];//去掉最后的逗号","
            insertValues = [insertValues substringToIndex:insertValues.length - 1];//去掉最后的逗号","
        }
        
        //组装sql语句,例如：@"insert into table_users (`real_name`,`user_name`, `user_pwd`, `user_school_id`, `label_code`) values('ff', '李三', '888888', '9999','hjk345678');";
        NSString *sql =[NSString stringWithFormat:@"insert into %@ (%@) values (%@);", table, insertNames, insertValues];
        
        
        BOOL success = NO;
        NSString *errMsg;
        //执行查询语句
        int status = mysql_query(self.sock, [sql UTF8String]);
        if (status == 0) {
            success = YES;
        }else{
            const char *error = mysql_error(self.sock);
            errMsg =[self decodeCString:error];
            success = NO;
        }
        callback?callback(success, errMsg):nil;
    });
    
    
}

//删除
-(void)delete:(NSString *)sql callback:(Success)callback{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //执行查询语句
        int status = mysql_query(self.sock, [sql UTF8String]);
        
        BOOL success =NO;
        NSString *errMsg;
        if (status == 0) {
            success = YES;
        }else{
            success = NO;
            errMsg = @"删除数据失败";
        }
        callback?callback(success, errMsg):nil;
        
    });


}

//查询sql
- (MYSQL_RES *)query22:(NSString *)sql {
    if (sql == nil) {
        return nil;
    }

    //执行查询语句
    int status = mysql_query(self.sock, [sql UTF8String]);

    MYSQL_RES *result = nil;
    if (status == 0) {
        result = mysql_store_result(self.sock);
    }
    return result;
}

//查询sql-异步
- (void)query:(NSString *)sql callback:(void(^)(MYSQL_RES *result, NSString *errorMsg))callback {

    if (sql == nil) {
        return ;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        //执行查询语句
        int status = mysql_query(self.sock, [sql UTF8String]);
        MYSQL_RES *result = nil;
        NSString *error;
        if (status == 0) {
            result = mysql_store_result(self.sock);
        }else{
            error=@"查询数据失败";
        }
        callback?callback(result, error):nil;
        
    });
    
}




//查询"table_vefication_code"表
- (void)queryFromVerificationCodeTable:(NSString *)sql callback:(void(^)(NSArray<VerificationCodeModel *> *list, NSString *errMsg))callback {

    @weakify(self);
    [self query:sql callback:^(MYSQL_RES *result, NSString *errorMsg) {
        @strongify(self);
        NSMutableArray *list = [NSMutableArray array];
        if (result) {//有数据
            //遍历每一行记录
            MYSQL_ROW row;
            while ((row = mysql_fetch_row(result))) {
                VerificationCodeModel *model = [[VerificationCodeModel alloc] init];
                //如果表中新增字段，那么这里的索引顺序应当改变
                model.mobile = [self decodeCString:row[1]];
                model.code = [self decodeCString:row[2]];
                [list addObject:model];
            }
        }
        callback?callback(list, errorMsg):nil;
    }];

}

//查询"table_labels"表
- (void)queryFromLabelsTable:(NSString *)sql callback:(void(^)(NSArray<LabelModel *> *list, NSString *errMsg))callback {
    [self query:sql callback:^(MYSQL_RES *result, NSString *errorMsg) {
        NSMutableArray *list = [NSMutableArray array];
        if (result) {
            //遍历每一行记录
            MYSQL_ROW row;
            while ((row = mysql_fetch_row(result))) {
                LabelModel *model = [[LabelModel alloc] init];
                //如果表中新增字段，那么这里的索引顺序应当改变
                model.labelUser = [self decodeCString:row[1]];
                model.labelId = [self decodeCString:row[2]];
                model.LabelDesc = [self decodeCString:row[3]];
                [list addObject:model];
            }
        }
        callback?callback(list, errorMsg):nil;
    }];

}


//查询"table_users"表
- (void)queryFromUserTable:(NSString *)sql callback:(void(^)(NSArray<UserModel *> *list, NSString *errMsg))callback{
    [self query:sql callback:^(MYSQL_RES *result, NSString *errorMsg) {
        NSMutableArray *list = [NSMutableArray array];
        if (result) {//有数据
            //遍历每一行记录
            MYSQL_ROW row;
            while ((row = mysql_fetch_row(result))) {
                UserModel *model = [[UserModel alloc] init];
                //如果表中新增字段，那么这里的索引顺序应当改变
                model.realName = [self decodeCString:row[1]];
                model.mobile = [self decodeCString:row[2]];
                model.userName = [self decodeCString:row[3]];
                model.userPwd = [self decodeCString:row[4]];
                model.schoolId = [self decodeCString:row[5]];
                model.labelCode = [self decodeCString:row[6]];
                [list addObject:model];
            }
        }
        callback?callback(list, errorMsg):nil;
    }];
}


//- (void)queryFromUserTable:(NSString *)sql callback:(void(^)(NSArray<UserModel *> * results))callback {
//
//    @weakify(self);
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        @strongify(self);
//        MYSQL_RES *result = [self query:sql];
//        NSMutableArray *list = [NSMutableArray array];
//        if (result) {//有数据
//            //遍历每一行记录
//            MYSQL_ROW row;
//            while ((row = mysql_fetch_row(result))) {
//                UserModel *model = [[UserModel alloc] init];
//                //如果表中新增字段，那么这里的索引顺序应当改变
//                model.realName = [self decodeCString:row[1]];
//                model.mobile = [self decodeCString:row[2]];
//                model.userName = [self decodeCString:row[3]];
//                model.userPwd = [self decodeCString:row[4]];
//                model.schoolId = [self decodeCString:row[5]];
//                model.labelCode = [self decodeCString:row[6]];
//                [list addObject:model];
//            }
//        }
//        callback?callback(list):nil;
//    });
//
//
//}


//更新"table_users"表
- (void )updateFromUserTable:(NSString *)sql callback:(Success)callback{

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //执行查询语句
        int status = mysql_query(self.sock, [sql UTF8String]);
        BOOL ok = NO;
        NSString *errMsg;
        if (status == 0) {
            ok = YES;
        }else{
            errMsg = @"更新数据失败";
            ok = NO;
        }
        callback?callback(ok, errMsg):nil;
    });

}


@end
