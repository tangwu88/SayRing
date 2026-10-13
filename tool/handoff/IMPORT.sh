#!/bin/sh
set -eu

package_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
if [ "$#" -ne 1 ]; then
  echo '用法：sh IMPORT.sh /path/to/new/SayRing（绝对路径）' >&2
  exit 1
fi
target=$1
case "$target" in
  /*) ;;
  *) echo '请传入绝对路径，例如：sh IMPORT.sh /path/to/SayRing' >&2; exit 1 ;;
esac
if [ -e "$target" ] || [ -L "$target" ]; then
  echo '目标目录已存在；为保护现有文件，导入已停止。' >&2
  exit 1
fi

cd "$package_dir"
shasum -a 256 -c SHA256SUMS.txt
IFS= read -r expected < COMMIT.txt
IFS= read -r branch < BRANCH.txt
case "$expected" in
  *[!0-9a-f]*|'') echo '无效的提交校验值。' >&2; exit 1 ;;
esac
if [ "${#expected}" -ne 40 ]; then
  echo '无效的提交长度。' >&2
  exit 1
fi
git check-ref-format "refs/heads/$branch"

git clone --branch "$branch" -- source.bundle "$target"
actual=$(git -C "$target" rev-parse HEAD)
if [ "$actual" != "$expected" ]; then
  echo '导入提交不一致；保留目录供排查，禁止继续构建。' >&2
  exit 1
fi
git -C "$target" fsck --connectivity-only --no-reflogs
git -C "$target" remote set-url origin https://github.com/tangwu88/SayRing.git
echo "已导入 Say Ring：$actual"
echo '下一步阅读 README.md 和 docs/SAY-RING-DEVELOPER-HANDOFF-20261005.md。'
