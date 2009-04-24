#!/bin/bash
#
# git-subtree.sh: split/join git repositories in subdirectories of this one
#
# Copyright (c) 2009 Avery Pennarun <apenwarr@gmail.com>
#
OPTS_SPEC="\
git subtree split <revisions> -- <subdir>
git subtree merge 

git subtree does foo and bar!
--
h,help   show the help
q        quiet
v        verbose
"
eval $(echo "$OPTS_SPEC" | git rev-parse --parseopt -- "$@" || echo exit $?)
. git-sh-setup
require_work_tree

quiet=
command=

debug()
{
	if [ -z "$quiet" ]; then
		echo "$@" >&2
	fi
}

assert()
{
	if "$@"; then
		:
	else
		die "assertion failed: " "$@"
	fi
}


#echo "Options: $*"

while [ $# -gt 0 ]; do
	opt="$1"
	shift
	case "$opt" in
		-q) quiet=1 ;;
		--) break ;;
	esac
done

command="$1"
shift
case "$command" in
	split|merge) ;;
	*) die "Unknown command '$command'" ;;
esac

revs=$(git rev-parse --default HEAD --revs-only "$@") || exit $?
dirs="$(git rev-parse --sq --no-revs --no-flags "$@")" || exit $?

#echo "dirs is {$dirs}"
eval $(echo set -- $dirs)
if [ "$#" -ne 1 ]; then
	die "Must provide exactly one subtree dir (got $#)"
fi
dir="$1"

debug "command: {$command}"
debug "quiet: {$quiet}"
debug "revs: {$revs}"
debug "dir: {$dir}"

cache_setup()
{
	cachedir="$GIT_DIR/subtree-cache/$$"
	rm -rf "$cachedir" || die "Can't delete old cachedir: $cachedir"
	mkdir -p "$cachedir" || die "Can't create new cachedir: $cachedir"
	debug "Using cachedir: $cachedir" >&2
}

cache_get()
{
	for oldrev in $*; do
		if [ -r "$cachedir/$oldrev" ]; then
			read newrev <"$cachedir/$oldrev"
			echo $newrev
		fi
	done
}

cache_set()
{
	oldrev="$1"
	newrev="$2"
	if [ -e "$cachedir/$oldrev" ]; then
		die "cache for $oldrev already exists!"
	fi
	echo "$newrev" >"$cachedir/$oldrev"
}

copy_commit()
{
	# We're doing to set some environment vars here, so
	# do it in a subshell to get rid of them safely later
	git log -1 --pretty=format:'%an%n%ae%n%ad%n%cn%n%ce%n%cd%n%s%n%n%b' "$1" |
	(
		read GIT_AUTHOR_NAME
		read GIT_AUTHOR_EMAIL
		read GIT_AUTHOR_DATE
		read GIT_COMMITTER_NAME
		read GIT_COMMITTER_EMAIL
		read GIT_COMMITTER_DATE
		export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE
		export GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE
		git commit-tree "$2" $3  # reads the rest of stdin
	) || die "Can't copy commit $1"
}

cmd_split()
{
	debug "Splitting $dir..."
	cache_setup || exit $?
	
	git rev-list --reverse --parents $revs -- "$dir" |
	while read rev parents; do
		newparents=$(cache_get $parents)
		debug
		debug "Processing commit: $rev / $newparents"
		
		git ls-tree $rev -- "$dir" |
		while read mode type tree name; do
			assert [ "$name" = "$dir" ]
			debug "  tree is: $tree"
			p=""
			for parent in $newparents; do
				p="$p -p $parent"
			done
			
			newrev=$(copy_commit $rev $tree "$p") || exit $?
			debug "  newrev is: $newrev"
			cache_set $rev $newrev
		done || exit $?
	done || exit $?
	
	exit 0
}

cmd_merge()
{
	die "merge command not implemented yet"
}

"cmd_$command"
