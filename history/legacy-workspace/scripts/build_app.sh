#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
stage_dir="$HOME/Library/Caches/ViolaDesktop/source"
app_name='Viola'
bundle_id='local.viola.desktop'
profile_name='ViolaDesktop'
if [[ "${1:-}" == '--parallel' ]]; then
  app_name='Viola 新版'
  bundle_id='local.viola.desktop.preview'
  profile_name='ViolaDesktop-Preview'
elif [[ -n "${1:-}" ]]; then
  print -u2 '用法：build_app.sh [--parallel]'
  exit 1
fi
if [[ -n "$(find "$project_dir/Sources" "$project_dir/packaging" -type f -flags +dataless -print -quit)" ]]; then
  print -u2 '项目含 iCloud 占位文件；请在 Finder 中保留下载后再构建。'
  exit 1
fi
mkdir -p "$stage_dir"
ditto "$project_dir/Sources" "$stage_dir/Sources"
ditto "$project_dir/packaging" "$stage_dir/packaging"
cp "$project_dir/Package.swift" "$stage_dir/Package.swift"
swift build --package-path "$stage_dir" -c release
binary_dir="$(swift build --package-path "$stage_dir" -c release --show-bin-path)"
app_dir="$HOME/Applications/$app_name.app"
if [[ -d "$app_dir" && "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_dir/Contents/Info.plist" 2>/dev/null)" != "$bundle_id" ]]; then
  print -u2 '同名应用不是本项目，构建停止以保留现有应用。'
  exit 1
fi
before_requirement=""
if [[ -x "$app_dir/Contents/MacOS/ViolaDesktop" ]]; then
  before_requirement="$(codesign -d -r- "$app_dir" 2>&1 | sed -n '/designated =>/p' || true)"
fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/Characters"
cp "$binary_dir/ViolaDesktop" "$app_dir/Contents/MacOS/ViolaDesktop"
cp -R "$stage_dir/Sources/ViolaDesktop/Resources/Characters/Viola" "$app_dir/Contents/Resources/Characters/"
cp "$project_dir/packaging/Info.plist" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $app_name" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $app_name" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ViolaProfileDirectory string $profile_name" "$app_dir/Contents/Info.plist"
xattr -cr "$app_dir"
codesign --force --sign - --identifier "$bundle_id" "$app_dir"
codesign --verify --deep --strict "$app_dir"
after_requirement="$(codesign -d -r- "$app_dir" 2>&1 | sed -n '/designated =>/p')"
if [[ -n "$before_requirement" && "$before_requirement" != "$after_requirement" ]]; then
  print -u2 "程序签名已变化：输入监控中的旧 Viola 条目可能仍显示开启，但不再匹配。"
  print -u2 "请在系统设置中移除旧条目，重新添加 $app_dir 并开启，按提示退出并重新打开。"
fi
if [[ ! -e "$project_dir/$app_name.app" && ! -L "$project_dir/$app_name.app" ]]; then
  ln -s "$app_dir" "$project_dir/$app_name.app"
fi
print "Built: $app_dir"
