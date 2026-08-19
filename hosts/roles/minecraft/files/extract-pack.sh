#!/bin/bash
# Extract the MeatballCraft server pack into the server dir, stripping the pack's
# single wrapper dir if present.  Args: <server_dir> <user> <group> <pack_id>
#
# Managed by MOSAIC — hosts/roles/minecraft. This lives in a file (run via the
# Ansible `script` module) on purpose: the pack uses shell arrays and ${#...},
# which collide with Ansible's arg splitter and Jinja templating when embedded
# inline in a `shell` task. A transferred script is neither split nor templated.
#
# On a version bump the pack ships a different mods/ + config/; copying over the
# top would leave mods that were *removed* upstream behind, and one orphaned
# 1.12.2 coremod reliably crashes the server. So we replace exactly the pack's
# own top-level entries (mods/, config/, scripts/, ...) and leave everything the
# pack doesn't ship — world/, the Forge install (libraries/, the loader jar),
# logs/ — untouched. <pack_id> (the pack's filename) is written to
# .pack-extracted so the play can detect the next version change.
set -euo pipefail

dir="$1"
user="$2"
group="$3"
pack_id="${4:-}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

unzip -q -o "$dir/server-pack.zip" -d "$tmp"

# The pack nests everything under one wrapper dir (e.g.
# "Meatballcraft-Server-prerelease-0.18.6.4/"); descend into it, but only when
# there is exactly one top-level entry and mods/ isn't already at the top.
# `find` (not shell arrays) keeps this readable.
count="$(find "$tmp" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
root="$tmp"
if [ "$count" -eq 1 ] && [ ! -d "$tmp/mods" ]; then
  only="$(find "$tmp" -mindepth 1 -maxdepth 1)"
  if [ -d "$only" ]; then
    root="$only"
  fi
fi

# A server pack MUST yield a mods/ dir — fail loudly rather than boot a bare
# server that loads only the loader's built-ins (the "only ten mods" symptom).
if [ ! -d "$root/mods" ]; then
  echo "ERROR: no mods/ found after extracting the server pack (root=$root)" >&2
  ls -la "$tmp" >&2
  exit 1
fi

# Replace only what the pack ships: drop each of the pack's top-level entries
# from the server dir first, so files (esp. mods) removed between versions don't
# linger. Anything the pack doesn't ship (world/, libraries/, the loader jar) is
# left in place. ${dir:?} guards against an empty path ever reaching rm.
while IFS= read -r entry; do
  name="$(basename "$entry")"
  rm -rf "${dir:?}/$name"
done < <(find "$root" -mindepth 1 -maxdepth 1)

cp -a "$root"/. "$dir"/
printf '%s\n' "$pack_id" > "$dir/.pack-extracted"
chown -R "$user:$group" "$dir"
