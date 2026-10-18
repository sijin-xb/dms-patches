# dms-patches

DankMaterialShell 的个人补丁集。基于 `v1.6.0-574-g5a480101c`。

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

### 0002 — 剪贴板监听回退

共享的 `wlcontext` dispatcher 不向 clipboard manager 投递 `ext_data_control` 选区事件，导致剪贴板历史不更新。补丁用独立 wayland 连接监听选区，写入走 `m.db`，避免和守护进程抢 bolt 文件锁。

涉及文件：`core/internal/server/clipboard/{manager,types}.go`。

## 应用

需要 DMS 源码树：

```fish
git clone https://github.com/AvengeMedia/DankMaterialShell
cd DankMaterialShell
git checkout 5a480101c
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
