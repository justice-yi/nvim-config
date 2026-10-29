#!/usr/bin/env bash
# LazyVim 一键部署脚本(Linux 通用,WSL/服务器均可)
# 用法: git clone <本仓库> 到任意位置, 进入目录执行 bash install.sh
set -euo pipefail
cd "$(dirname "$0")"

REPO_URL="$(git remote get-url origin 2>/dev/null || true)"

echo "== [1/6] 系统依赖(需要 sudo;无 sudo 时跳过,只要 git/curl/tar 存在即可)"
if command -v sudo >/dev/null 2>&1; then
  sudo apt-get update -qq || true
  sudo apt-get install -y git curl unzip tar build-essential ripgrep fd-find || true
fi

# fd 是可选依赖:Telescope 找不到 fd 会自动退回 ripgrep,缺了不影响使用
export PATH="$HOME/.local/bin:$PATH"
mkdir -p ~/.local/bin ~/.local/opt
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sf "$(command -v fdfind)" ~/.local/bin/fd
fi

echo "== [2/6] PATH 持久化"
grep -q '\.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# github release 下载:直连不通时自动改走 api.github.com 资产通道
gh_asset() { # gh_asset <owner/repo> <精确资产名> <输出文件>
  local repo="$1" name="$2" out="$3" id
  curl -sfL --connect-timeout 8 -o "$out" "https://github.com/$repo/releases/latest/download/$name" && return 0
  echo "  (github.com 直连不通,改走 api.github.com 通道)"
  id=$(curl -s https://api.github.com/repos/$repo/releases/latest |
    python3 -c "import json,sys; d=json.load(sys.stdin); print(next(a['id'] for a in d['assets'] if a['name']=='$name'))")
  curl -sfL -H "Accept: application/octet-stream" -o "$out" "https://api.github.com/repos/$repo/releases/assets/$id"
}

echo "== [3/6] Neovim 官方稳定版(装 ~/.local/opt,免 sudo)"
if ! command -v nvim >/dev/null 2>&1; then
  gh_asset neovim/neovim nvim-linux-x86_64.tar.gz /tmp/nvim-install.tar.gz
  rm -rf ~/.local/opt/nvim-linux-x86_64
  tar -C ~/.local/opt -xzf /tmp/nvim-install.tar.gz
  ln -sf ~/.local/opt/nvim-linux-x86_64/bin/nvim ~/.local/bin/nvim
  rm -f /tmp/nvim-install.tar.gz
fi
nvim --version | head -1

echo "== [4/6] git 通道:github.com https 不通且已配 GitHub SSH key 时,自动切 SSH"
if ! curl -s -o /dev/null -m 5 https://github.com; then
  if ssh -o ConnectTimeout=5 -o BatchMode=yes -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then
    git config --global url."git@github.com:".insteadOf "https://github.com/"
    echo "  已设置 url.insteadOf: github https -> ssh"
  else
    echo "  [警告] github https 不通且 SSH key 未配,插件安装可能失败"
    echo "  解决:把 ~/.ssh/id_ed25519.pub 内容贴到 github.com -> Settings -> SSH keys 后重跑本脚本"
  fi
fi

echo "== [5/6] 配置目录 ~/.config/nvim"
if [ -d ~/.config/nvim ] && [ "$PWD" != "$(cd ~/.config/nvim && pwd)" ]; then
  mv ~/.config/nvim ~/.config/nvim.bak.$(date +%s)
  echo "  已备份原有配置"
fi
if [ -n "$REPO_URL" ] && [ "$PWD" != "$(cd ~/.config/nvim 2>/dev/null && pwd)" ]; then
  git clone "$REPO_URL" ~/.config/nvim
fi

echo "== [6/6] 可选组件"
# pyright(Python 跳转/诊断;不需要可删这两行)
if ! command -v pyright-langserver >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  npm install -g --prefix ~/.local pyright || true
fi
# win32yank(仅 WSL 需要:nvim 剪贴板打通到 Windows)
if grep -qi microsoft /proc/version 2>/dev/null && ! command -v win32yank.exe >/dev/null 2>&1; then
  gh_asset equalsraf/win32yank win32yank-x64.zip /tmp/win32yank.zip && \
    unzip -o /tmp/win32yank.zip -d ~/.local/bin win32yank.exe && \
    chmod +x ~/.local/bin/win32yank.exe && rm -f /tmp/win32yank.zip
fi

echo ""
echo "== 完成。运行 nvim,首次启动会自动安装全部插件 =="
