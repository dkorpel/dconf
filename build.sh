#!/usr/bin/env bash
# Rebuild a Marp deck: html + pdf next to the source, and the copy under docs/
# that GitHub Pages serves.
#
#   ./build.sh dconf26/lightning.md
#   ./build.sh                        # rebuild every deck listed in DECKS below
#
# There is no Node on this machine, so this drives the marp-cli bundled inside the
# VS Code Marp extension using VS Code's own Electron as the Node runtime, and Edge
# as the browser Puppeteer needs for PDF output.
set -euo pipefail
cd "$(dirname "$0")"

# source.md -> docs/ subdirectory
DECKS=(
	"dconf25/lightning.md:dconf25-lightning"
	"dconf26/lightning.md:dconf26-lightning"
)

THEME=dconf25/dracula.css

find_marp_cli() {
	local ext
	for ext in "$USERPROFILE"/.vscode/extensions/marp-team.marp-vscode-*; do
		if [ -f "$ext/node_modules/@marp-team/marp-cli/marp-cli.js" ]; then
			echo "$ext/node_modules/@marp-team/marp-cli/marp-cli.js"
			return 0
		fi
	done
	echo "error: marp-cli not found; is the Marp for VS Code extension installed?" >&2
	return 1
}

CODE="$LOCALAPPDATA/Programs/Microsoft VS Code/Code.exe"
[ -f "$CODE" ] || { echo "error: VS Code not found at $CODE" >&2; exit 1; }
CLI=$(find_marp_cli)

export ELECTRON_RUN_AS_NODE=1
export CHROME_PATH="${CHROME_PATH:-C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe}"

marp() { "$CODE" "$CLI" --theme "$THEME" --allow-local-files "$@"; }

build() {
	local src=$1 docsdir=$2
	local dir base
	dir=$(dirname "$src")
	base=$(basename "$src" .md)

	echo "==> $src"
	marp "$src" --html -o "$dir/$base.html"
	marp "$src" --pdf  -o "$dir/$base.pdf"

	mkdir -p "docs/$docsdir"
	cp "$dir/$base.html" "docs/$docsdir/index.html"

	# Exports reference images by relative path rather than inlining them, so any
	# image directory the deck uses has to sit next to the published index.html.
	local imgdir
	for imgdir in $(grep -oE '\(([a-zA-Z0-9_]+)/[^)]*\.(png|jpg|jpeg|gif|svg)' "$src" |
	                sed 's/^(//; s#/.*##' | sort -u); do
		if [ -d "$dir/$imgdir" ]; then
			echo "    images: $imgdir/"
			mkdir -p "docs/$docsdir/$imgdir"
			cp "$dir/$imgdir"/* "docs/$docsdir/$imgdir/"
		fi
	done
	echo "    -> docs/$docsdir/index.html"
}

if [ $# -gt 0 ]; then
	for src in "$@"; do
		found=
		for deck in "${DECKS[@]}"; do
			if [ "${deck%%:*}" = "$src" ]; then
				build "${deck%%:*}" "${deck##*:}"
				found=1
			fi
		done
		[ -n "$found" ] || { echo "error: $src is not listed in DECKS in $0" >&2; exit 1; }
	done
else
	for deck in "${DECKS[@]}"; do
		build "${deck%%:*}" "${deck##*:}"
	done
fi
