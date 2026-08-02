#!/bin/bash
# Extract the MeatballCraft server pack into the server dir, stripping the pack's
# single wrapper dir if present.  Args: <server_dir> <user> <group>
#
# Managed by MOSAIC — hosts/roles/minecraft. This lives in a file (run via the
# Ansible `script` module) on purpose: the pack uses shell arrays and ${#...},
# which collide with Ansible's arg splitter and Jinja templating when embedded
# inline in a `shell` task. A transferred script is neither split nor templated.
set -euo pipefail

dir="$1"
user="$2"
group="$3"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

unzip -q -o "$dir/server-pack.zip" -d "$tmp"

# The pack nests everything under one wrapper dir (e.g.
# "Meatballcraft-Server-prepatch-0.18.1/"); descend into it, but only when there
# is exactly one top-level entry and mods/ isn't already at the top. `find` (not
# shell arrays) keeps this readable.
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

cp -a "$root"/. "$dir"/
touch "$dir/.pack-extracted"
chown -R "$user:$group" "$dir"
