# IPAInstaller (iOS 9 / armv7 / iPhone 4S)

越狱 iPhone 4S (iOS 9) 上的一键安装工具：读取指定**设备绝对路径**的 IPA，调用 `ipainstaller` 安装。

> 重要：iOS 应用沙盒内无法以 root 执行 `su`/`ipainstaller`。因此本项目以 **Theos 越狱应用** 形式编译，安装到 `/Applications/IPAInstaller.app`（系统应用路径），并使用平台应用 entitlements。最终产物主要是 **.deb**；同时附带一个未签名的 IPA 包（仅作打包参考，安装建议用 .deb）。

## 功能
- 配置并保存 IPA 绝对路径（写入 `/var/mobile/ipainstaller.conf`，默认 `/var/mobile/Documents/install.ipa`）
- 点击“安装 IPA”后执行：`echo alpine | su root -c /bin/sh /tmp/ipainstaller_run.sh`，脚本内部调用 `/usr/bin/ipainstaller '<路径>'`
- 界面显示执行日志与退出状态

## 设备前置条件（iPhone 4S 已越狱）
1. 已安装 **ipainstaller**（Cydia 包：`com.autopear.installipa`，提供 `/usr/bin/ipainstaller`）
2. root 密码为默认 **`alpine`**（如已修改，需在 `IPAInstaller.mm` 中修改密码字符串并重新编译）
3. 目标 IPA 文件已放在设备上的**绝对路径**，例如 `/var/mobile/Documents/install.ipa`

## 通过 GitHub Actions 编译（无需 Mac）
1. 在 GitHub 新建一个仓库（或使用现有仓库）。
2. 将本目录 `IPAInstaller/` 的**全部内容**推送到仓库根目录（确保 `.github/workflows/build.yml` 在根目录下）。
   ```bash
   cd IPAInstaller
   git init
   git add .
   git commit -m "IPAInstaller for iOS9 armv7"
   git branch -M main
   git remote add origin https://github.com/<你的用户名>/<仓库名>.git
   git push -u origin main
   ```
3. 打开仓库页面 → **Actions** → 选择 “Build IPAInstaller (iOS 9 armv7)” → **Run workflow**（或等待 push 自动触发）。
4. 构建完成后，在该次运行的 **Artifacts** 下载 `IPAInstaller-iOS9-armv7`，内含：
   - `*.deb`（推荐，用于安装到越狱设备 `/Applications`）
   - `IPAInstaller-unsigned.ipa`（未签名打包产物，参考）

## 安装到 iPhone 4S
推荐用 **.deb**：
```bash
# 在电脑上（确保能 SSH 到手机，OpenSSH 已安装）
scp com.example.ipainstaller_1.0_iphoneos-arm.deb root@<手机IP>:/var/root/
ssh root@<手机IP> "dpkg -i /var/root/com.example.ipainstaller_1.0_iphoneos-arm.deb && uicache"
```
默认 SSH 密码 `alpine`。

或者用 Filza/iFile 在手机上打开 `.deb` 安装后执行 `uicache`（或注销/重启 SpringBoard）。

## 使用
1. 将要安装的 IPA 放到设备绝对路径，如 `/var/mobile/Documents/install.ipa`。
2. 打开 **IPAInstaller**，确认/修改路径，点“保存”（可选）。
3. 点“安装 IPA”，查看日志。安装完成后新应用会出现在桌面（可能需要 `uicache`/注销）。

## 自定义
- 修改默认路径/配置文件路径/root 密码：编辑 `IPAInstaller.mm` 顶部常量与 `installIPAAtPath:` 中的密码。
- 修改 Bundle ID / 包名：编辑 `Resources/Info.plist`、`control`、`Makefile`。
- 目标系统/架构：`Makefile` 中 `TARGET := iphone:clang:9.3:9.0` 与 `ARCHS := armv7`。

## 构建实现要点（Linux + Theos，已跑通）
本项目当前由 `.github/workflows/build-linux.yml` 在 **ubuntu-latest** 上构建（macOS 运行器排队严重，`build.yml` 仅保留手动触发作为备用）：

1. 用 Theos 官方 Linux 安装器装好交叉工具链（`theos/toolchain/linux/iphone`）。
2. 从 `theos/sdks` 稀疏拉取 **`iPhoneOS9.3.sdk`**（`install-sdk 9.3` 已不再提供该版本）。
3. **补一个缺失的文件**：该 SDK 缺 `usr/lib/system/liblaunch.tbd`，而 `libSystem` 的再导出列表引用它，否则链接报
   `ld: file not found: /usr/lib/system/liblaunch.dylib`。workflow 会用 curl 从 10.3 SDK 下载该 `.tbd` 补进去。
   > 不要直接换用 `iPhoneOS10.3.sdk`：它的 `libobjc` tbd 缺 `_objc_msgSend_stret`，armv7 链接会失败。
4. entitlements 必须用 `IPAInstaller_CODESIGN_FLAGS = -Sentitlements.plist`（Theos 不认 `xxx_ENTITLEMENTS`），
   让 `ldid` 把 `platform-application` / `no-sandbox` 嵌进二进制，否则应用会在沙盒里以 mobile 身份运行、`su` 失败。
5. `make clean package FINALPACKAGE=1` 产出 `.deb`；再从 `.theos/_/Applications/IPAInstaller.app` 打包出未签名 `.ipa`。

## 安全与免责声明
- 本工具通过明文密码 `alpine` 管道传给 `su`，仅适用于你自己的越狱测试设备。请勿在不可信设备上使用默认密码。
- 安装 IPA 可能涉及签名/来源风险，请仅安装你有权使用的软件。
