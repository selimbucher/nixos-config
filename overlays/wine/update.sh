#!/usr/bin/env bash
# Moves the plug-in Wine to a newer branch of the giang17/wine fork and
# replays patches/ on it. See README.md.
#
#   overlays/wine/update.sh             newest d2d1-dcomp-* branch
#   overlays/wine/update.sh <branch>    that branch
#   overlays/wine/update.sh --continue  after resolving a conflict
#   overlays/wine/update.sh --export    after changing or adding commits on the
#                                       work tree's `update` branch
#
# source.json and patches/ are rewritten only once every patch is in place.
set -euo pipefail

dir=$(cd "$(dirname "$0")" && pwd)
work=${XDG_CACHE_HOME:-$HOME/.cache}/wine-update
field() { sed -n "s/^ *\"$1\": \"\([^\"]*\)\".*/\1/p" "$dir/source.json"; }
g() { git -C "$work" "$@"; }

url=$(field url)
old_ref=$(field ref)
old_rev=$(field rev)

if [ ! -d "$work/.git" ]; then
  echo "Cloning $url (commits and trees only) into $work ..."
  git clone -q --filter=blob:none --no-checkout "$url" "$work"
fi

stuck() {
  cat <<EOF

A patch does not apply on $branch. Resolve it in $work:
  - fix the conflicted files, \`git -C $work add\` them, then run
    $0 --continue
  - or, if the patch is no longer needed there, \`git -C $work am --skip\`, then
    $0 --continue
  - or give up with \`git -C $work am --abort\`; nothing in $dir changed.
EOF
  exit 1
}
am() { g -c user.name=wine-update -c user.email=wine-update@localhost am "$@"; }

if [ "${1:-}" = --continue ] || [ "${1:-}" = --export ]; then
  branch=$(cat "$work/.update-branch")
  if [ "$1" = --continue ] && [ -d "$work/$(g rev-parse --git-path rebase-apply)" ]; then
    am --continue || stuck
  fi
else
  # every branch, so the blobs a patch's index lines name stay reachable
  # for git am's 3-way merge
  g fetch -q --filter=blob:none origin '+refs/heads/*:refs/remotes/origin/*'
  newest=$(g for-each-ref --format='%(refname:lstrip=3)' 'refs/remotes/origin/d2d1-dcomp-*' \
    | sort -V | tail -1)
  branch=${1:-$newest}
  g rev-parse -q --verify "origin/$branch" >/dev/null || { echo "no branch $branch at $url" >&2; exit 1; }
  echo "$branch" > "$work/.update-branch"
  g am --abort 2>/dev/null || true
  g checkout -q -f -B update "origin/$branch"
  echo "Replaying $(ls "$dir"/patches/*.patch | wc -l) patches from $old_ref onto $branch ..."
  am -3 -q "$dir"/patches/*.patch || stuck
fi

base=$(g rev-parse "origin/$branch")
version=$(g show "$base:VERSION" | sed 's/^Wine version //')

# a long Subject: header continues on lines that start with a space
old_subjects=$(for f in "$dir"/patches/*.patch; do
  awk '/^Subject: \[PATCH\] /{s=substr($0, 18); on=1; next} on && /^ /{s=s $0; next} on{print s; exit}' "$f"
done | sort)
new_subjects=$(g log --format=%s "$base..update" | sort)

rm -f "$dir"/patches/*.patch
g format-patch -q --zero-commit --no-signature --full-index -N -o "$dir/patches" "$base..update"
cat > "$dir/source.json" <<EOF
{
  "url": "$url",
  "ref": "$branch",
  "rev": "$base",
  "version": "$version"
}
EOF

echo
echo "Now on $branch ($version), $(ls "$dir"/patches/*.patch | wc -l) patches."
dropped=$(comm -23 <(echo "$old_subjects") <(echo "$new_subjects"))
if [ -n "$dropped" ]; then
  echo "Not carried over (already in $branch, or skipped with git am --skip):"
  echo "$dropped" | sed 's/^/  /'
fi

# file:macro of each version nixpkgs-wine has to match
version_defines=(
  dlls/mscoree/mscoree_private.h:WINE_MONO_VERSION
  dlls/appwiz.cpl/addons.c:GECKO_VERSION
  libs/vkd3d/config.h:PACKAGE_VERSION
)
for define in "${version_defines[@]}"; do
  file=${define%%:*}
  macro=${define##*:}
  old_value=$(g show "$old_rev:$file" | sed -n "s/^#define $macro \"\(.*\)\"/\1/p")
  new_value=$(g show "$base:$file" | sed -n "s/^#define $macro \"\(.*\)\"/\1/p")
  if [ "$old_value" != "$new_value" ]; then
    case $file in
      libs/*)
        echo "WARNING: Wine's bundled vkd3d changed from $old_value to $new_value; d2d1's shaders" \
          "are compiled at build time with nixpkgs-wine's vkd3d, so bump the nixpkgs-wine input" \
          "to a nixpkgs with vkd3d $new_value."
        ;;
      *)
        echo "WARNING: $macro changed from $old_value to $new_value; bump the nixpkgs-wine input" \
          "to a nixpkgs that ships $new_value."
        ;;
    esac
  fi
done
echo "Next: build and test (README.md)."
