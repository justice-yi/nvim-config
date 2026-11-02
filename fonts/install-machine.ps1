# 机器级安装 JetBrainsMono Nerd Font(MobaXterm 等老式 GDI 程序只认机器级字体)
# 用法:在管理员 PowerShell 中运行本脚本,或在 WSL 中由 install.sh 触发(UAC 弹窗点"是")
$ErrorActionPreference = 'Stop'
$src = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$styleMap = @{
  'Regular'    = ''
  'Bold'       = ' Bold'
  'Italic'     = ' Italic'
  'BoldItalic' = ' Bold Italic'
}
foreach ($f in Get-ChildItem "$src\JetBrainsMonoNerdFont-*.ttf") {
  Copy-Item $f.FullName "$env:WINDIR\Fonts\$($f.Name)" -Force
  $style = $f.BaseName -replace '^JetBrainsMonoNerdFont-', ''
  $regName = 'JetBrainsMono NF' + $styleMap[$style] + ' (TrueType)'
  New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' `
    -Name $regName -Value "$env:WINDIR\Fonts\$($f.Name)" -PropertyType String -Force | Out-Null
  Write-Output ("installed: " + $regName)
}
Write-Output 'DONE: 注销重新登录后所有程序可见'
