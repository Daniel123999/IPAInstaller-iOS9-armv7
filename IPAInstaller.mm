#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/stat.h>

static NSString *const kConfigPath = @"/var/mobile/ipainstaller.conf";
static NSString *const kDefaultIPAPath = @"/var/mobile/Documents/install.ipa";

@interface AppDelegate : UIResponder <UIApplicationDelegate, UITextViewDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UITextField *pathField;
@property (nonatomic, strong) UIButton *installButton;
@property (nonatomic, strong) UIButton *saveButton;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor whiteColor];

    CGFloat w = vc.view.bounds.size.width;
    CGFloat pad = 12.0;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(pad, 28, w - pad * 2, 24)];
    title.text = @"IPA 安装器";
    title.font = [UIFont boldSystemFontOfSize:18];
    [vc.view addSubview:title];

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(pad, 54, w - pad * 2, 36)];
    hint.text = @"IPA 绝对路径（保存后写入 /var/mobile/ipainstaller.conf）";
    hint.font = [UIFont systemFontOfSize:12];
    hint.textColor = [UIColor darkGrayColor];
    hint.numberOfLines = 2;
    [vc.view addSubview:hint];

    self.pathField = [[UITextField alloc] initWithFrame:CGRectMake(pad, 92, w - pad * 2 - 70, 34)];
    self.pathField.borderStyle = UITextBorderStyleRoundedRect;
    self.pathField.font = [UIFont systemFontOfSize:13];
    self.pathField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.pathField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.pathField.placeholder = kDefaultIPAPath;
    self.pathField.text = [self loadConfiguredPath];
    [vc.view addSubview:self.pathField];

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.frame = CGRectMake(w - pad - 62, 92, 62, 34);
    [self.saveButton setTitle:@"保存" forState:UIControlStateNormal];
    [self.saveButton addTarget:self action:@selector(savePath) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:self.saveButton];

    self.installButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.installButton.frame = CGRectMake(pad, 134, w - pad * 2, 40);
    self.installButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.installButton setTitle:@"安装 IPA" forState:UIControlStateNormal];
    [self.installButton addTarget:self action:@selector(runInstall) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:self.installButton];

    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(pad, 182, w - pad * 2, vc.view.bounds.size.height - 182 - pad)];
    self.logView.editable = NO;
    self.logView.font = [UIFont fontWithName:@"Courier" size:12];
    self.logView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    self.logView.text = @"就绪。点击“安装 IPA”执行：su alpine -> ipainstaller <路径>\n"
                        @"提示：需越狱设备已安装 ipainstaller (com.autopear.installipa)，"
                        @"且 root 密码为 alpine。\n";
    [vc.view addSubview:self.logView];

    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    return YES;
}

- (NSString *)loadConfiguredPath {
    NSError *err = nil;
    NSString *s = [NSString stringWithContentsOfFile:kConfigPath encoding:NSUTF8StringEncoding error:&err];
    if (s) {
        s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length > 0) return s;
    }
    return kDefaultIPAPath;
}

- (void)savePath {
    NSString *path = [self.pathField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (path.length == 0) path = kDefaultIPAPath;
    NSError *err = nil;
    BOOL ok = [path writeToFile:kConfigPath atomically:YES encoding:NSUTF8StringEncoding error:&err];
    if (ok) {
        [self appendLog:[NSString stringWithFormat:@"已保存配置: %@ -> %@", path, kConfigPath]];
    } else {
        [self appendLog:[NSString stringWithFormat:@"保存失败: %@", err.localizedDescription]];
    }
}

- (void)runInstall {
    NSString *ipaPath = [self.pathField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (ipaPath.length == 0) ipaPath = kDefaultIPAPath;

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:ipaPath]) {
        [self appendLog:[NSString stringWithFormat:@"错误：文件不存在 %@", ipaPath]];
        return;
    }
    if (![fm fileExistsAtPath:@"/usr/bin/ipainstaller"]) {
        [self appendLog:@"错误：未找到 /usr/bin/ipainstaller，请先在 Cydia 安装 ipainstaller (com.autopear.installipa)。"];
        return;
    }

    self.installButton.enabled = NO;
    [self appendLog:[NSString stringWithFormat:@"开始安装: %@", ipaPath]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *out = [self installIPAAtPath:ipaPath];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self appendLog:out];
            [self appendLog:@"完成。"];
            self.installButton.enabled = YES;
        });
    });
}

- (NSString *)installIPAAtPath:(NSString *)ipaPath {
    // Escape single quotes for shell.
    NSString *safe = [ipaPath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    // Use a temp script to avoid complex quoting through su -c.
    NSString *scriptPath = @"/tmp/ipainstaller_run.sh";
    NSString *script = [NSString stringWithFormat:
        @"#!/bin/sh\n"
        @"/usr/bin/ipainstaller '%@' 2>&1\n"
        @"echo \"__EXIT__:$?\"\n", safe];
    NSError *err = nil;
    if (![script writeToFile:scriptPath atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
        return [NSString stringWithFormat:@"写入临时脚本失败: %@", err.localizedDescription];
    }
    chmod([scriptPath UTF8String], 0755);

    // su reads password from stdin on iOS/OpenSSH; feed "alpine" via pipe.
    NSString *cmd = [NSString stringWithFormat:@"/bin/echo alpine | /usr/bin/su root -c /bin/sh %@", scriptPath];
    NSString *result = [self runShell:cmd];
    [[NSFileManager defaultManager] removeItemAtPath:scriptPath error:nil];
    return result.length ? result : @"(无输出，可能 su/ipainstaller 执行失败；请检查 root 密码或权限)";
}

- (NSString *)runShell:(NSString *)command {
    FILE *fp = popen([command UTF8String], "r");
    if (!fp) return [NSString stringWithFormat:@"popen 失败: %s", strerror(errno)];
    NSMutableString *out = [NSMutableString string];
    char buf[512];
    while (fgets(buf, sizeof(buf), fp) != NULL) {
        [out appendString:[NSString stringWithUTF8String:buf] ?: @""];
        if (out.length > 20000) { [out appendString:@"\n...(输出截断)..."]; break; }
    }
    int status = pclose(fp);
    [out appendFormat:@"\n[status=%d]", status];
    return out;
}

- (void)appendLog:(NSString *)msg {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm:ss"];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [df stringFromDate:[NSDate date]], msg ?: @""];
    self.logView.text = [self.logView.text stringByAppendingString:line];
    NSRange bottom = NSMakeRange(self.logView.text.length - 1, 1);
    [self.logView scrollRangeToVisible:bottom];
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
