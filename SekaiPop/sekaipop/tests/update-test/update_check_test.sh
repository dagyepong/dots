#!/bin/sh
# Runs scripts/system/update-check.sh against a throw-away local "GitHub":
# installed copy (no marker / marker / behind / apply / failures), the repo layout
# (shell folder = <clone>/sekaipop), and a symlinked folder. Needs git only.
#   sh tests/update-test/update_check_test.sh
here=$(cd "$(dirname "$0")/../.." && pwd)
t=$(mktemp -d) && trap 'rm -rf "$t"' EXIT
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
expect() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (wanted '$3', got: $(echo "$2" | tr '\n' ' '))" ;; esac; }

export HOME="$t/home" SEKAIPOP_REPO="$t/remote.git" GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME/.config/quickshell" "$t/work/sekaipop/scripts/system"
cd "$t/work" && git init -q -b main . && cp "$here/scripts/system/update-check.sh" sekaipop/scripts/system/
echo 1.0.0 > sekaipop/VERSION && echo "import QtQuick" > sekaipop/shell.qml && touch install.sh
git add -A && git commit -qm first && git clone -q --bare . "$t/remote.git"
git remote add origin "$t/remote.git" && git fetch -q && git branch -q -u origin/main
inst="$HOME/.config/quickshell/sekaipop"; cp -a sekaipop "$inst"
S="sh $inst/scripts/system/update-check.sh"

export XDG_CACHE_HOME="$t/cache"
expect "no marker: managed + unknown" "$($S check)" "unknown=yes"
expect "check names the newest version (rev)" "$($S check)" "rev=$(git -C "$t/work" rev-parse --short HEAD)"
[ -z "$($S seen)" ] && ok "seen: empty at first" || bad "seen not empty"
$S seen abc1234; expect "seen: stores and reads back" "$($S seen)" "abc1234"
printf 'commit=%s\nrepo=%s\nref=main\n' "$(git rev-parse HEAD)" "$t/remote.git" > "$inst/.source"
expect "marker = remote: current" "$($S check)" "status=current"
echo 1.0.1 > sekaipop/VERSION && git commit -qam second && git push -q origin main
expect "remote moved: behind" "$($S check)" "status=behind"
$S apply >/dev/null; rc=$?
[ "$rc" = 0 ] && ok "apply exits 0" || bad "apply exit $rc"
[ "$(cat "$inst/VERSION")" = 1.0.1 ] && ok "files updated" || bad "files not updated"
[ -d "$inst.previous" ] && ok "previous copy kept" || bad "no previous copy"
expect "after apply: current" "$($S check)" "status=current"
SEKAIPOP_REPO=/nonexistent $S apply >/dev/null; [ $? != 0 ] && [ -f "$inst/shell.qml" ] && ok "bad repo: fails, install untouched" || bad "bad repo"
mkdir -p "$t/real" && cp -a "$inst" "$t/real/s" && ln -s "$t/real/s" "$HOME/.config/quickshell/lnk"
sh "$HOME/.config/quickshell/lnk/scripts/system/update-check.sh" apply >/dev/null; [ $? != 0 ] && ok "symlinked folder: refuses" || bad "symlink"
G="sh $t/work/sekaipop/scripts/system/update-check.sh"
expect "repo layout: git mode" "$($G info)" "git=yes"
expect "repo layout: rev is the upstream head" "$($G check)" "rev="
cd "$t/work" && git fetch -q && echo "// local" >> sekaipop/shell.qml && git commit -qam local && git push -q origin main
expect "repo layout: current after push" "$($G check)" "status=current"
[ $fail = 0 ] && echo "all passed" || { echo "FAILED"; exit 1; }
