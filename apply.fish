#!/usr/bin/env fish
# 在 DMS 源码树里应用全部补丁并编译安装。需在源码根目录运行。
# 用法: ./apply.fish /path/to/DankMaterialShell

set src $argv[1]
if test -z "$src"
    echo "usage: apply.fish /path/to/DankMaterialShell" >&2
    exit 1
end

set here (status dirname)
cd $src; or exit 1

for p in $here/*.patch
    echo "applying "(basename $p)
    git apply $p
    or begin
        echo "failed: $p" >&2
        exit 1
    end
end

cd core
make build; or exit 1
echo "built: $src/core/bin/dms"
echo "install with: sudo install -D -m 755 $src/core/bin/dms /usr/bin/dms"
