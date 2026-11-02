# LazyVim 速查手册(makefile / py / xml 查看向)

部署:Neovim 0.12 + LazyVim(32 插件,25 个语法解析器,版本由 lazy-lock.json 锁定)。
本手册随仓库走,任何机器 clone 后自带。

## 1. 打开文件

```bash
nvim Makefile           # 打开/编辑
nvim -R config.xml      # 只读查看(防误改)
nvim .                  # 当前目录(文件树)
nvim a.py b.py c.xml    # 多文件
```

## 2. 活下去的最低要求

| 操作 | 按键 |
|---|---|
| 万能键 | **`空格` 停 1 秒,弹出全部快捷键菜单**(忘了就按它) |
| 退出 | `Esc` → `:q` 回车(保存 `:w`,保存退出 `:wq`,放弃修改退出 `:q!`) |
| 移动 | 方向键即可;翻页 `Ctrl-d` / `Ctrl-u` |
| 跳到第 N 行 | `:123` 回车 |
| 搜索 | `/关键词` 回车,`n` 下一个 `N` 上一个 |

## 3. 看代码高频键

| 功能 | 按键 | 场景 |
|---|---|---|
| 文件树 | `空格 e` | 方向键选文件,回车打开 |
| **本文件符号大纲** | `空格 s s` | Makefile 的 target / py 的函数 / xml 的节点直接跳 |
| 全目录 grep | `空格 /` | 跨文件搜内容(走 rg) |
| 找文件名 | `空格 f f` | 模糊匹配路径 |
| 折叠/展开 | `za`;`zR` 全展开 `zM` 全折叠 | 大 XML 按 layer 折叠看结构 |
| 跳定义 | `gd`,返回 `Ctrl-o` | py(已配 pyright) |
| 悬浮文档 | `K` | 光标在函数上 |
| 全部诊断 | `空格 x x` | 错误/警告列表 |
| 全部快捷键 | `空格 k` | which-key 搜索 |

## 4. 日常维护

```bash
# 升级全部插件(nvim 内)
:Lazy update
# 升级后把版本锁推上 git(保证其他机器装出一致环境)
cd ~/.config/nvim && git add -A && git commit -m "chore: lazy update" && git push

# 改个人配置:都在 ~/.config/nvim/
#   lua/plugins/treesitter.lua   语法解析器清单(现有 make/xml/python)
#   lua/config/options.lua       基础选项
#   lua/plugins/                 每个文件一个插件配置
```

## 5. 新机器部署(一条命令)

```bash
git clone https://github.com/justice-yi/nvim-config.git /tmp/nv && bash /tmp/nv/install.sh
# 断流环境(公司网)用镜像版:
git clone https://ghfast.top/https://github.com/justice-yi/nvim-config.git /tmp/nv && bash /tmp/nv/install.sh
```

装完跑一次 `nvim`(自动装插件,几分钟)→ `source ~/.bashrc` → 重启终端软件选字体
**JetBrainsMono Nerd Font**(WSL 上字体已由脚本自动装入 Windows)。

## 6. 本环境网络须知(github 断流)

公司网对 github.com HTTPS 间歇断流,已固化的绕行方案:

| 通道 | 用途 | 状态 |
|---|---|---|
| api.github.com | 下载 release 二进制(nvim/win32yank) | 稳定 |
| codeload.github.com | 下载仓库 tarball / treesitter parser | 稳定 |
| SSH 22 端口 | git push/pull(主 WSL 已配 key) | 稳定 |
| ghfast.top 镜像 | git clone 传输层改写(存于 ~/.gitconfig) | 稳定 |

- 撤销镜像改写:`git config --global --unset url.https://ghfast.top/https://github.com/.insteadOf`
- `:TSInstall` 卡住(转圈不出结果):终端跑 `fix-ts` 再回 nvim 重试(改走 codeload;`:Lazy update` 覆盖补丁后需重跑)

## 7. 常见问题

| 症状 | 原因与解法 |
|---|---|
| 图标变方块 | 终端没选 Nerd 字体;重启终端软件,字体选 JetBrainsMono Nerd Font |
| nvim 里复制到不了 Windows | win32yank 未装;WSL 里重跑仓库 install.sh 即补 |
| 大 XML(几 MB)无高亮/无补全 | LazyVim bigfile 保护机制,正常现象,不是坏了 |
| 打开 py/xml 无语法颜色 | parser 未装;`fix-ts` 后 `:TSInstall make xml python` |
| Command 'nvim' not found | 新装后当前终端 PATH 未刷新;`source ~/.bashrc` |
| lazy.nvim 报 "Origin has changed" | `git -C ~/.local/share/nvim/lazy/lazy.nvim remote set-url origin https://github.com/folke/lazy.nvim.git` |
