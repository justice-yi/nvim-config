#!/usr/bin/env bash
# LazyVim 一键部署脚本(Linux 通用,WSL/服务器均可)
# 用法: git clone <本仓库> 到任意位置, 进入目录执行 bash install.sh
# 网络受限环境(公司网对 github.com 断流)自动降级: 直连 -> SSH -> 镜像
set -euo pipefail
cd "$(dirname "$0")"

REPO_URL="$(git remote get-url origin 2>/dev/null || true)"
# 本机是 SSH 地址时转为 https(公开仓库免认证克隆,新机器无需配 key)
REPO_URL="${REPO_URL/git@github.com:/https://github.com/}"

echo "== [1/7] 系统依赖(需要 sudo;无 sudo 时跳过,只要 git/curl/tar 存在即可)"
if command -v sudo >/dev/null 2>&1; then
  sudo apt-get update -qq || true
  sudo apt-get install -y git curl unzip tar build-essential ripgrep fd-find || true
fi

export PATH="$HOME/.local/bin:$PATH"
mkdir -p ~/.local/bin ~/.local/opt
grep -q '\.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# fd 可选:Telescope 找不到 fd 会退回 ripgrep,缺了不影响使用
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sf "$(command -v fdfind)" ~/.local/bin/fd
fi

echo "== [2/7] git 通道选择"
MIRROR="https://ghfast.top/https://github.com"
if curl -s -o /dev/null -m 5 https://github.com; then
  echo "  github.com 直连可用"
elif ssh -o ConnectTimeout=5 -o BatchMode=yes -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then
  git config --global url."git@github.com:".insteadOf "https://github.com/"
  echo "  直连不通,SSH key 可用 -> git 全部改走 SSH"
else
  git config --global url."$MIRROR/".insteadOf "https://github.com/"
  echo "  [注意] 直连与 SSH 均不可用 -> 改走镜像 $MIRROR (仅影响传输,remote 仍记录官方地址)"
fi

# release 下载:直连不通时走 api.github.com 资产通道(公司网实测稳定)
gh_asset() { # gh_asset <owner/repo> <精确资产名> <输出文件>
  local repo="$1" name="$2" out="$3" id
  curl -sfL --connect-timeout 8 -o "$out" "https://github.com/$repo/releases/latest/download/$name" && return 0
  id=$(curl -s https://api.github.com/repos/$repo/releases/latest |
    python3 -c "import json,sys; d=json.load(sys.stdin); print(next(a['id'] for a in d['assets'] if a['name']=='$name'))")
  curl -sfL -H "Accept: application/octet-stream" -o "$out" "https://api.github.com/repos/$repo/releases/assets/$id"
}

echo "== [3/7] Neovim 官方稳定版(装 ~/.local/opt,免 sudo)"
if ! command -v nvim >/dev/null 2>&1; then
  gh_asset neovim/neovim nvim-linux-x86_64.tar.gz /tmp/nvim-install.tar.gz
  rm -rf ~/.local/opt/nvim-linux-x86_64
  tar -C ~/.local/opt -xzf /tmp/nvim-install.tar.gz
  ln -sf ~/.local/opt/nvim-linux-x86_64/bin/nvim ~/.local/bin/nvim
  rm -f /tmp/nvim-install.tar.gz
fi
nvim --version | head -1

echo "== [4/7] 配置目录 ~/.config/nvim"
if [ -d ~/.config/nvim ] && [ "$PWD" != "$(cd ~/.config/nvim && pwd)" ]; then
  mv ~/.config/nvim ~/.config/nvim.bak.$(date +%s)
  echo "  已备份原有配置"
fi
if [ -n "$REPO_URL" ] && [ "$PWD" != "$(cd ~/.config/nvim 2>/dev/null && pwd)" ]; then
  git clone "$REPO_URL" ~/.config/nvim
fi

echo "== [5/7] 引导 lazy.nvim(镜像/SSH 通道已在上一步配好,clone 会自动走)"
[ -d ~/.local/share/nvim/lazy/lazy.nvim ] || \
  git clone -q --filter=blob:none https://github.com/folke/lazy.nvim.git ~/.local/share/nvim/lazy/lazy.nvim

echo "== [6/7] 可选组件与辅助命令"
# fix-ts:github 断流环境下 parser 下载改走 codeload 通道(幂等)
# 用法:首次 nvim 启动装完插件后,若 :TSInstall 卡住,终端跑 fix-ts 再回 nvim 重试
cat > ~/.local/bin/fix-ts <<'FIXTS'
#!/usr/bin/env bash
f=~/.local/share/nvim/lazy/nvim-treesitter/lua/nvim-treesitter/install.lua
[ -f "$f" ] || { echo "nvim-treesitter 未安装,先跑一次 nvim 让插件装完"; exit 1; }
if grep -q codeload "$f"; then echo "已是 codeload 通道,无需处理"; exit 0; fi
sed -i "s|local target = string.format('%s/archive/%s.tar.gz', url, revision)|local target = url:gsub('github%.com/', 'codeload.github.com/') .. '/tar.gz/' .. revision|" "$f" \
  && echo "补丁完成。进 nvim 执行 :TSInstall <语言> 即可(如 :TSInstall make xml python)"
FIXTS
chmod +x ~/.local/bin/fix-ts

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
# Nerd 字体(仅 WSL:装入 Windows 用户字体库,终端图标必需;本仓库自带字体文件)
if grep -qi microsoft /proc/version 2>/dev/null && [ -d fonts ] && [ -d /mnt/c ]; then
  WINUSER=$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
  FONTDIR="/mnt/c/Users/$WINUSER/AppData/Local/Microsoft/Windows/Fonts"
  if [ -n "$WINUSER" ] && [ -d "/mnt/c/Users/$WINUSER" ]; then
    mkdir -p "$FONTDIR"
    for f in fonts/JetBrainsMonoNerdFont-*.ttf; do
      [ -f "$f" ] || continue
      cp -f "$f" "$FONTDIR/"
      style=$(basename "$f" .ttf | sed 's/JetBrainsMonoNerdFont-//')
      /mnt/c/Windows/System32/reg.exe add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts" \
        /v "JetBrainsMono Nerd Font $style (TrueType)" /t REG_SZ \
        /d "C:\\Users\\$WINUSER\\AppData\\Local\\Microsoft\\Windows\\Fonts\\$(basename "$f")" \
        /f >/dev/null 2>&1 || true
    done
    echo "  字体已装入 Windows(重启终端软件后选 JetBrainsMono Nerd Font)"
  fi
fi
# MobaXterm 等老式 GDI 程序只认「机器级」字体:弹出 UAC 一键机器级安装(点"是";可跳过)
if grep -qi microsoft /proc/version 2>/dev/null && [ -f fonts/install-machine.ps1 ]; then
  if ! /mnt/c/Windows/System32/reg.exe query "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" 2>/dev/null | tr -d '\r' | grep -q 'C:\\\\Windows\\\\Fonts\\\\JetBrains'; then
    PS1WIN=$(wslpath -w "$PWD/fonts/install-machine.ps1" 2>/dev/null || true)
    if [ -n "$PS1WIN" ]; then
      echo "  [需要 MobaXterm 的话] 请在弹出的 UAC 窗口点[是]安装机器级字体(用 Windows Terminal 可跳过)"
      powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','$PS1WIN')" || true
      echo "  机器级安装完成(若点了是),注销重新登录后生效"
    fi
  fi
fi

echo "== [7/7] 完成"
echo "  运行 nvim,首次启动自动安装全部插件(受 lazy-lock.json 锁定,版本与本机一致)"
echo "  treesitter parser 若下载失败(github archive 断流),重开 nvim 会自动续装"
