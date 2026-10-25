<p align="right"><strong>简体中文</strong> · <a href="differences-vs-upstream.md">English</a></p>

# 相对上游 Passport Mic 的改动

- 上游项目：[MatchlessHeroHx/ai-passport-mic](https://github.com/MatchlessHeroHx/ai-passport-mic)（MIT）
- 基线提交：`143a22a chore: publish only what Passport Mic needs`
- 本版本目标：把「Chatterfly 听写遥控器」改成「通用语音输入话筒」，默认对接**豆包输入法**

## 一句话总结

**固件零改动，只改了电脑端。** 上游把设备固件、BLE 协议、ADPCM 编码、界面全部保持原样；
本版本只重整了 `companion/` 里的 Mac 端程序：语音热键从右 Control 换成右 Option、
按键注入从派生助手进程改成进程内直接发送、并让程序在缺少权限时降级而不是退出。

## 逐文件改动

| 文件 | 改动 | 原因 |
| --- | --- | --- |
| `companion/passport_mic.py` | 按键注入改为进程内 Quartz 直接发送；删除 `KEY` 常量；启动自检改为 `AXIsProcessTrusted()`，缺失时打印警告并跳过按键；新增 `PM_VOICE_KEY` / `PM_KEY_COMMAND` 两个环境变量；界面文案改为「听写软件」 | 子进程不继承辅助功能授权（见下节证据） |
| `companion/chatterfly_key.swift` | **删除** | 功能内联进 Python，不再需要独立二进制 |
| `companion/build-mac.sh` | 去掉 `swiftc` 编译与 `codesign` 步骤，只保留 venv | 没有 Swift 助手需要编译 |
| `companion/requirements.txt` | 新增 `pyobjc-framework-Quartz==10.3.2` | 进程内发键需要 Quartz 绑定 |
| `companion/Start.command` | 去掉 `chatterfly-key --request-access || exit 1` 前置检查 | 原检查会让启动在未授权时直接失败 |
| `companion/bridge_status.py` | 修正辅助功能提示文案 | 提示对象从助手二进制改为 Terminal |
| `README.md` / `README.zh_CN.md` | 重写 | 面向本版本的使用方式 |
| `docs/differences-vs-upstream.*`、`NOTICE` | 新增 | 说明改造来源与版权归属 |

**未改动**：`main/`、`components/bsp/`、`sdkconfig.defaults`、`partitions.csv`、`tests/`、`tools/`
以及全部固件行为（含 BLE 服务 UUID、FPM1 帧格式、ADPCM 参数、屏幕界面）。

## 行为差异

| 项目 | 上游 | 本版本 |
| --- | --- | --- |
| 语音热键 | 右 Control（Chatterfly） | **右 Option（豆包输入法）**，可用 `PM_VOICE_KEY=ctrl` 切回 |
| 按键注入方式 | 派生 `chatterfly-key` 子进程 | 桥接进程内 `CGEventPost` |
| 缺少辅助功能权限 | 启动即失败退出 | 打印警告，音频继续工作，按键跳过 |
| 启动前置检查 | 要求助手已授权 | 无 |
| 依赖 | bleak / numpy / pyserial / sounddevice | 追加 `pyobjc-framework-Quartz` |

UP = ⌘Z、DOWN = 回车、OK = 语音键的映射语义不变。

## 为什么必须改按键注入方式

macOS 的辅助功能授权按「责任进程」判定。实测（macOS 27，Apple Silicon）：

| 场景 | 结果 |
| --- | --- |
| Terminal → Python → `chatterfly-key` | 可用（继承 Terminal 的授权） |
| launchd → Python → `chatterfly-key` | 失败（`AXIsProcessTrusted()=false`） |
| App bundle → Python → `chatterfly-key` | 失败（多层后责任链断） |
| Python 自己 `CGEventPost` | 可用（权限就是它自己的） |

也就是说：**权限不会穿透子进程**。上游依赖「派生助手」的结构，只在从终端启动时成立；
一旦换到开机自启或 App 封装，按键就会静默失效。改成进程内发送后，权限归属与发键进程合一，
不再依赖调用层级。

## 试过但未采用的方案

| 方案 | 结果 |
| --- | --- |
| launchd LaunchAgent 直接启动 Python | 蓝牙报 `BLE is not authorized`，辅助功能为 false |
| 封装 `PassportMic.app` + LaunchAgent | 后台启动时 `AXIsProcessTrusted()=false` |
| 封装 app 后用 `open -a` 启动 | 自建 ad-hoc bundle 不被执行，且仍无授权 |
| app 持权 + 命名管道让 app 发键 | 架构成立，但 app 在后台启动拿不到授权 |
| 重新签名后重复授权 | ad-hoc 签名每次重编译 `cdhash` 都变，TCC 条目立即失效 |

结论：当前 macOS 上，**后台进程无法获得蓝牙与辅助功能权限**，因此本版本不提供
「开机零配置自启」，改为 `Start.command` 手动/登录项启动。

## 其他实测记录

- 设备按 OK 后发 `START`，主机必须在 2 秒内回 `A`，否则设备退回待机（屏幕表现为闪一下回到原界面）
- 心跳 `P` 每 500 ms，设备 3 秒无心跳停止推流
- 音频为 20 ms/帧、320 采样、164 字节 ADPCM；拥塞时丢帧补静音
- 固件烧录时若中途断开，需 `erase-region 0x0 0x10000` 让芯片停在 ROM 下载模式后分片重写
- 该板电池持续供电，拔 USB 不会断电，冷启动只能靠长按电源键约 2 秒

## 兼容上游用法

若仍想用 Chatterfly：

```bash
PM_VOICE_KEY=ctrl companion/Start.command
```

快捷键即可回到右 Control。若要改成「按住说话」而非「按一下切换」，
设置 `PM_KEY_COMMAND=voice-down`（需配合设备端的按住语义改造，当前固件是切换式）。
