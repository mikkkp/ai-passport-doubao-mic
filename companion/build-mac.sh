#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
python3 -m venv .venv
.venv/bin/python -m pip install -r companion/requirements.txt
echo '依赖安装完成。用 companion/Start.command 启动。'
