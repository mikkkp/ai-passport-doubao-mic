<p align="right"><strong>简体中文</strong> · <a href="README.md">English</a></p>

# AI Passport 豆包语音话筒

把 [FoloToy AI Passport](https://github.com/FoloToy/ai-passport) 这张可穿戴卡片改造成**无线语音输入话筒**：
按一下 OK 开始说话，文字直接出现在 Mac 当前光标处。

本项目是 [Passport Mic](https://github.com/MatchlessHeroHx/ai-passport-mic)（MIT）的二次开发版本。
上游把设备做成了「Chatterfly 听写遥控器」，本版本改成**豆包输入法 + 右 Option 触发**的通用方案，
并去掉了对独立按键助手二进制的依赖。改造清单见[相对上游的改动](docs/differences-vs-upstream.zh_CN.md)。

## 它做什么

```text
AI Passport  ──BLE(16 kHz IMA ADPCM, 加密绑定)──▶  Mac 菜单栏程序  ──▶  BlackHole 2ch  ──▶  豆包输入法
  OK / UP / DOWN                                    音频解码 + 按键注入
```

| 设备按键 | 电脑端动作 | 实际效果 |
| --- | --- | --- |
| 按一下 OK | 发一次**右 Option** | 豆包开始语音输入；设备同时开始收音 |
| 再按一下 OK | 再发一次右 Option | 豆包结束识别并上屏，设备停止收音 |
| 按 UP | 发 ⌘Z | 撤销上一段上屏文字 |
| 按 DOWN | 发回车 | 发送 / 换行 |

音频路径固定写进 `BlackHole 2ch`，因此任何能选麦克风的软件都能用这台设备说话；
把豆包的语音快捷键设为**右 Option** 即获得「按一下就出字」的体验。

## 硬件

| 项 | 规格 |
| --- | --- |
| MCU | ESP32-C3，8 MB Flash，无 PSRAM |
| 音频 | ES8311，麦克风 + 扬声器，I2S 全双工 |
| 显示 | ST7789P3 240 × 320 |
| 输入 | 上 / 下 / 确定 三键，GPIO0 ADC 电阻梯 |
| 无线 | 2.4 GHz Wi-Fi + Bluetooth 5 LE |
| 电池 | 500 mAh + CW2017 电量计 |

> ESP32-C3 没有经典蓝牙、没有 USB OTG，ESP-IDF 5.5.3 也不支持 LE Audio，
> 所以它**无法**作为系统原生蓝牙麦克风或 USB 声卡麦克风出现。必须有电脑端伴随程序，
> 这也是本项目存在的根本原因。

## 安装

### 1. 烧录固件

```bash
source ~/esp/esp-idf/export.sh      # 需要 ESP-IDF 5.5.3
./tools/validate.sh --firmware      # 生成 build/FoloToy-AI-Passport-full.bin
python -m esptool --chip esp32c3 -p /dev/cu.usbmodemXXXX -b 460800 \
  write_flash 0x0 build/FoloToy-AI-Passport-full.bin
```

烧录注意：这块板带电池，**拔 USB 不等于断电**。若烧录中途断开导致镜像不完整，
需要先擦除引导区（`erase-region 0x0 0x10000`）让芯片停在 ROM 下载模式，再分片写入。

### 2. 安装 BlackHole 2ch

从 [existential.audio](https://existential.audio/blackhole/) 获取（当前需 Homebrew 或 Discord），
或用官方直链安装包：

```text
https://existential.audio/downloads/BlackHole2ch-0.7.1.pkg
```

装完确认 `系统设置 → 声音` 里出现 `BlackHole 2ch`。

### 3. 安装电脑端依赖

```bash
bash companion/build-mac.sh          # 创建 .venv 并安装依赖
```

### 4. 授权（两个位置）

| 位置 | 允许谁 | 用途 |
| --- | --- | --- |
| 隐私与安全性 → 蓝牙 | Terminal | 扫描并连接设备 |
| 隐私与安全性 → 辅助功能 | Terminal | 注入右 Option / ⌘Z / 回车 |

权限跟随**启动程序的 App**，所以用 Terminal 启动时授给 Terminal 即可，不需要单独授权 Python。

### 5. 启动

```bash
companion/Start.command             # 或在 Finder 里双击
```

菜单栏出现图标后，设备屏幕会从「暂未检测到 Mac」变为已连接。

### 6. 配置豆包输入法

1. 安装并启用豆包输入法（macOS 版）
2. 把它的语音快捷键设为**右 Option**
3. 麦克风选 `BlackHole 2ch`（若输入法不能单独选，就把系统默认输入设备改成它）

## 日常使用

```text
按 OK → 说话 → 再按 OK → 文字出现在光标处
```

- 设备关机再开机后，菜单栏程序会自动重连，无需操作
- 电脑重启后需要启动一次 `companion/Start.command`（见下方说明）
- 日志：`~/Library/Logs/PassportMic/bridge.log`

## 已知限制

1. **无法开机自动零配置启动**。macOS（实测 27）不给后台 `launchd` 进程发放蓝牙与辅助功能权限，
   自建 ad-hoc 签名 App 在后台启动时同样拿不到。把 `Start.command` 加进登录项是当前可行做法，
   但仍需要 Terminal 参与。详见[相对上游的改动](docs/differences-vs-upstream.zh_CN.md)。
2. **音质是语音级**。16 kHz / 4 bit ADPCM，适合说话，不适合录音乐。
3. **功耗与续航未实测**。500 mAh 电池 + 持续 BLE 传输的实际时长还没有测量数据。
4. **UP / DOWN 会直接作用于当前焦点窗口**。误触 DOWN 会插入回车，使用时注意。
5. **调试困难**。固件把日志全部关闭且 USB 串口被数据协议独占，`idf.py monitor` 没有输出。

## 目录结构

```text
companion/          Mac 端：菜单栏程序、BLE 桥接、按键注入
main/               固件应用层：录音状态机、BLE 协议、ADPCM、界面
components/bsp/     板级驱动（音频、显示、按键、电池、I2C）
docs/               协议说明、硬件指南、改造对照
tests/              host tests 与协议互通测试
tools/              validate.sh、固件归档与校验
```

## 许可

MIT，沿用上游 [FoloToy AI Passport](https://github.com/FoloToy/ai-passport) 与
[Passport Mic](https://github.com/MatchlessHeroHx/ai-passport-mic)。
原始版权声明保留在 [LICENSE](LICENSE) 与 [NOTICE](NOTICE) 中。
