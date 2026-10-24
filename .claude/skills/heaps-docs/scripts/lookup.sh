#!/bin/sh
# Looks up the API of Heaps, HxBit, DomKit, hlsteam and Hide in the Heapheapheaps documentation.
#
#   lookup.sh <words>          types whose name or summary contains all the words (case-insensitive)
#   lookup.sh --page <Type>    the Markdown page of a type (full name: h2d.Flow, hxbit.Serializer...)
#   lookup.sh --source <Type>  the source files of a type in the installed library (haxelib libpath),
#                              platform versions included (Window.js.hx, Window.hl.hx...)
#   lookup.sh --refresh        downloads the indexes again
#
# The indexes and pages are downloaded from GitHub once, then read from the cache
# ($HEAPS_DOCS_CACHE, default ~/.cache/heaps-docs). $HEAPS_DOCS_URL changes the source (a folder
# path works too: the content/ folder of a local clone of Heapheapheaps).
set -e

BASE=${HEAPS_DOCS_URL:-https://raw.githubusercontent.com/Jonathan-HETEAU/Heapheapheaps/main/content}
CACHE=${HEAPS_DOCS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/heaps-docs}
LIBS="heaps hxbit domkit hlsteam hide"
# The indexes link the published site; the same files are under content/ in the repository.
SITE=https://jonathan-heteau.github.io/heapheapheaps

fetch() { # fetch <path under content/> <destination>
	mkdir -p "$(dirname "$2")"
	case $BASE in
		http*) curl -fsSL "$BASE/$1" -o "$2.tmp" && mv "$2.tmp" "$2" ;;
		*) cp "$BASE/$1" "$2" ;;
	esac
}

indexes() {
	for lib in $LIBS; do
		[ -f "$CACHE/llms/$lib.txt" ] || fetch "llms/$lib.txt" "$CACHE/llms/$lib.txt" || { echo "cannot download the index of $lib from $BASE" >&2; exit 1; }
	done
}

# "lib<TAB>name<TAB>path<TAB>summary" for each type of the indexes.
entries() {
	indexes
	for lib in $LIBS; do
		sed -n 's/^- \[\([^]]*\)\](\([^)]*\))\(: \(.*\)\)\{0,1\}$/\1\t\2\t\4/p' "$CACHE/llms/$lib.txt" |
			sed "s#$SITE/##; s#^#$lib\t#"
	done
}

entry() { # entry <Type>: the line of exactly this type
	entries | awk -F '\t' -v n="$1" '$2 == n { print; exit }'
}

case $1 in
"" | -h | --help)
	sed -n '2,/^set -e/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
	;;
--refresh)
	rm -rf "$CACHE/llms" "$CACHE/api"
	indexes
	echo "indexes downloaded in $CACHE"
	;;
--page)
	[ -n "$2" ] || { echo "usage: $0 --page <Type>" >&2; exit 2; }
	e=$(entry "$2")
	[ -n "$e" ] || { echo "no type named $2; search with: $0 $(echo "$2" | sed 's/.*\.//')" >&2; exit 1; }
	path=$(echo "$e" | cut -f3)
	[ -f "$CACHE/$path" ] || fetch "$path" "$CACHE/$path"
	cat "$CACHE/$path"
	;;
--source)
	[ -n "$2" ] || { echo "usage: $0 --source <Type>" >&2; exit 2; }
	e=$(entry "$2")
	[ -n "$e" ] || { echo "no type named $2" >&2; exit 1; }
	lib=$(echo "$e" | cut -f1)
	dir=$(haxelib libpath "$lib" 2>/dev/null) || { echo "library $lib is not installed (haxelib libpath $lib)" >&2; exit 1; }
	base="$dir$(echo "$2" | tr . /)"
	if [ -f "$base.hx" ]; then
		echo "$base.hx"
		# Platform versions of the same module (hxd/Window.js.hx, hxd/Window.hl.hx...).
		ls "$base".*.hx 2>/dev/null || true
		exit 0
	fi
	# A type declared in the module of another type (h2d.FlowAlign is in h2d/Flow.hx).
	pkg=$(echo "$2" | sed 's/\.[^.]*$//' | tr . /)
	name=$(echo "$2" | sed 's/.*\.//')
	[ "$pkg" = "$name" ] && pkg=
	grep -lE "^[[:space:]]*(@:[^ ]+[[:space:]]+)*(extern |private |final )*(class|interface|enum|typedef|abstract|enum abstract)[[:space:]]+$name\b" "$dir$pkg"/*.hx 2>/dev/null | head -1 ||
		{ echo "source of $2 not found under $dir$pkg" >&2; exit 1; }
	;;
*)
	entries | awk -F '\t' -v q="$*" '
		BEGIN { n = split(tolower(q), w, " ") }
		{
			s = tolower($2 " " $4)
			for( i = 1; i <= n; i++ ) if( index(s, w[i]) == 0 ) next
			printf "%-8s %s: %s\n", $1, $2, $4
			if( ++found == 40 ) { print "... (more: add words)"; exit }
		}
		END { if( !found ) print "nothing found for: " q }'
	;;
esac
