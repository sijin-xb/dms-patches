# dms-patches

DankMaterialShell 的个人补丁集。基于 `v1.6.0-581-ga9dd3be40`。

## 补丁

### 0001 — 音量曲线线性化

DMS 的音量滑块在 10% 时实际输出 -60 dB，几乎无声。原因是 quickshell 写入 PipeWire 前把音量立方（`quickshell/src/services/pipewire/node.cpp`），而读取时不还原，读写刻度不一致。

补丁在 DMS 的 QML 层做反向补偿：写入前开立方、读取后立方。滑块百分比直接对应线性增益。

| 滑块 | 实际增益 | dB |
|---|---|---|
| 10% | 0.10 | -20.0 |
| 15% | 0.15 | -16.5 |
| 50% | 0.50 | -6.0 |
| 100% | 1.00 | 0.0 |

涉及文件：`Services/AudioService.qml`、`DMSShellIPC.qml`、`Modules/OSD/{VolumeOSD,MicVolumeOSD}.qml`、`Modules/ControlCenter/Widgets/{AudioSliderRow,AudioDeviceTile}.qml`、`Modules/DBar/Widgets/ControlCenterButton.qml`。

### 0002 — 剪贴板：独立会话与条目恢复

共享的 `wlcontext` dispatcher 不向 clipboard manager 投递 `ext_data_control` 选区事件，导致剪贴板历史完全不更新（[#3812](https://github.com/AvengeMedia/DankMaterialShell/issues/3812)）。上游的 `2592e2f33` 修的是发送侧，r574 实测仍然失败。

补丁新增 `clipboard.Session`：一条长期存在的 wayland 连接，同时负责监听选区变化和接管选区。两个角色放在同一条连接上，`IsOwner()` 才能可靠区分「compositor 回显自己刚设的选区」和「别的应用复制了内容」，否则每次从历史恢复都会被当成新复制记录下来。

同时修复 `TouchEntry` 的既有缺陷：它原先走 `storeEntry`，会去重并分配新序号，导致「从面板选一条历史 → ID 立刻失效 → 粘贴出来还是旧内容」。现在原地更新，ID 保持不变。

`GetHistory` 随之改为按时间戳排序。它原本依赖 key 顺序（即序号）来体现新旧，原地更新后序号不再变化，面板第一条就不会是你刚选中的那条。

涉及文件：`core/internal/clipboard/{clipboard,session}.go`、`core/internal/server/clipboard/{manager,types}.go`。

## 应用

需要 DMS 源码树：

```fish
git clone https://github.com/AvengeMedia/DankMaterialShell
cd DankMaterialShell
git checkout a9dd3be40
git submodule update --init --recursive
```

应用补丁并编译：

```fish
for p in ~/dev/dms-patches/*.patch
    git apply $p
end

cd core
make build
sudo install -D -m 755 bin/dms /usr/bin/dms
```

重启 DMS：

```fish
pkill -f 'dms run'
setsid dms run -d --daemon-child >/tmp/dms.log 2>&1 < /dev/null &
```

## 键盘音量键

补丁后 DMS 滑条用线性刻度，但 `wpctl set-volume 5%+` 仍按 quickshell 的立方刻度步进，两者对不上。把 niri 的音量绑定改走 DMS IPC：

```kdl
XF86AudioRaiseVolume { spawn "dms" "ipc" "call" "audio" "increment" "5"; }
XF86AudioLowerVolume { spawn "dms" "ipc" "call" "audio" "decrement" "5"; }
```

## 升级注意

`paru -Syu` 升级 `dms-shell-git` 会覆盖 `/usr/bin/dms`，补丁失效。上游有新提交时：

1. 重新 checkout 上游版本
2. `git apply` 补丁；冲突则手工解决
3. `make build` 并安装

## 回滚

```fish
sudo pacman -S dms-shell-git
```

## 许可

补丁跟随上游 DMS 的 MIT 许可。上游版权归 Avenge Media LLC。
