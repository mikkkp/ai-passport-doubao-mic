#!/bin/bash
# Starts Passport Mic in the menu bar. The Terminal window can be closed afterwards.
cd -- "$(dirname -- "$0")/.." || exit 1
if [[ ! -x .venv/bin/python ]]; then
    echo '请先执行 companion/build-mac.sh 完成安装。'
    exit 1
fi
if pgrep -f 'companion/menubar.py' >/dev/null; then
    echo 'Passport Mic 已经在运行，请看屏幕右上角的菜单栏图标。'
    exit 0
fi
nohup .venv/bin/python companion/menubar.py >/dev/null 2>&1 &
disown
echo 'Passport Mic 已在菜单栏启动，可以关闭这个窗口。日志：~/Library/Logs/PassportMic/bridge.log'
