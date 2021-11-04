#!/usr/bin/env bash
# 
# BSD 2-Clause License
# 
# Copyright (c) 2021, Paco Pascal <me@pacopascal.com>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


inform() {
	local prefix=$1
	shift
	printf "::: %-8.8s %s\n" $prefix "$@" >&2
}

error() {
	printf "!!! ERROR  %s\n"  "$@" >&2
}

warn() {
	printf "??? WARNING  %s\n"  "$@" >&2
}


# Renames a sys file to our repo filename
# Usage: sys2git [filename]
sys2git() {
	echo ${@##${DEST}} | sed 's/^./_/'
}

# Renames a filename in our repo to a system file
# Usage: git2sys [filename]
git2sys() {
	echo -n $DEST
	echo "$@" | sed 's/^_/./'
}


# Generic file system functions
makedir() {
	local dir="$@"
	if ! [ -e "$dir" ]; then
		inform MKDIR "$dir"
		mkdir -p "$dir"
	elif [ -e "$dir" ] && ! [ -d "$dir" ]; then
		error "$dir exists but isn't a directory."
		return 1
	fi
	return 0
}

installfile() {
	local src=$1
	local dest=$2

	# If destination exists, it must be a regular file
	if [ -e "$dest" ] && ! [ -f "$dest" ]; then
		error "'$dest' exists but isn't a regular file."
		return 1 # Failure
	fi
	
	# If source exists, it must be a regular file
	if [ -e "$src" ] && ! [ -f "$src" ]; then
		error "'$src' exists but isn't a regular file."
		return 1 # Failure
	fi

	if [ -f "$src" ]; then
		inform COPY "$dest"
		cp -p "$src" "$dest" >&2
	else
		error "'$src' doesn't exist."
		return 1 # Failure
	fi
	
	return 0 # Success
}


# Tracking functions
untrack() {
	local sysfile=$@
	local file=$(sys2git "$sysfile")

	if ! [ -e "$file" ]; then
		# warn "'$file' isn't being tracked."
		return 0
	fi
	
	inform RM "$file"
	(git rm -rf "$file" && git commit -m "RM $file") > /dev/null 2>&1
	return 0 # Success
}

track_file() {
	local sysfile=$@
	local file=$(sys2git "$sysfile")

	if ! (makedir $(dirname "$file") && installfile "$sysfile" "$file"); then
		rm -f "$file"
		rmdir --ignore-fail-on-non-empty $(dirname $file)
		return 1 # Failure
	fi

	(git add "$file" && git commit -m "TRACKING $file") > /dev/null 2>&1
	return 0 # Success
}

track_dir() {
	local sysdir=$@
	local dir=$(sys2git "$sysdir")
	local watchfile="$dir/_WATCH"
	
	if ! [ -e "$sysdir" ]; then
		error "'$sysdir' doesn't exist."
		return 1 # Failure
	elif ! [ -d "$sysdir" ]; then
		error "'$sysdir' isn't a directory. Cannot track."
		return 1 # Failure
	fi
	
	if [ -e "$dir" ] && ! [ -d "$dir" ]; then
		error "'$dir' is in your repo but is not a directory."
		return 1 # Failure
	fi

	makedir "$dir" || return 1

	inform WATCH "$dir"
	touch "$watchfile"
	(git add "$watchfile" && git commit -m "WATCH $dir") > /dev/null 2>&1

	return 0 # Success
}

track() {
	local result=0

	case $(stat -c '%F' "$@" 2> /dev/null) in
		'directory')
			track_dir "$@"
			result=$?
		;;
		'regular file')
			track_file "$@"
			result=$?
		;;
		*)
			error "'$@' is an unknown file type."
			return 1 # Failure
		;;
	esac

	return $result
}

# Dotfile functions
_list() {
	local type=$1
	IFS=$'\n'; for orig in _*; do
				   for subs in $(find ${orig} -type $type); do
					   echo $subs
				   done
			   done
}

dirlist() {
	_list d
}

filelist() {
	_list f
}


pulldir() {
	local dir="$@"
	local sysdir=$(git2sys "$dir")
	
	if ! [ -d "$sysdir" ]; then
		untrack "$sysdir"
		return 0
	fi
	   
	IFS=$'\n'; for f in `ls "$sysdir"`; do
				   if ! [ -e "$dir/$f" ]; then
					   track "$sysdir/$f"
				   fi
			   done
}

pull2git() {
	IFS=$'\n'; for file in `filelist`; do
				   local sysfile=$(git2sys $file)

				   if [ "$(basename $file)" = "_WATCH" ]; then
					   pulldir "$(dirname $file)"
				   elif ! [ -e "$sysfile" ]; then
					   untrack "$sysfile"
				   elif ! diff -u "$sysfile" "$file" > /dev/null 2>&1; then
					   track "$sysfile"
				   fi
			   done
}

push2sys() {
	IFS=$'\n'; for file in `filelist`; do
				   local sysfile=$(git2sys $file)
				   if [ "$(basename $file)" = "_WATCH" ]; then
					   true
				   elif ! diff -u "$sysfile" "$file" > /dev/null 2>&1; then
					   makedir "$(dirname "$sysfile")"
					   installfile "$file" "$sysfile"
				   fi
			   done
}

pulldiff() {
	local sysfile=$@
	local file=$(sys2git "$sysfile")

	if [ -n "$sysfile" ]; then
		[ -f $sysfile ] && diff -u "$file" "$sysfile"
		return 0
	fi
	   
	IFS=$'\n'; for file in `filelist`; do
				   sysfile=$(git2sys $file)
				   if [ $(basename $file) != "_WATCH" ] && ! diff -u "$file" "$sysfile" > /dev/null 2>&1 ; then
					   diff -u "$file" "$sysfile" | less
				   fi
			   done
	return 0
}

# Main

TOP=$(dirname `realpath $0`)
[ -z "$DEST" ] && DEST=~/
DEST=$(realpath $DEST)/
cd $TOP
set -e

case $1 in
	push)
		push2sys
		;;
	pull)
		pull2git
		;;
	diff)
		pulldiff $2
		;;
	track)
		shift
		for f in $@; do
			track "$f"
		done
		;;
	untrack)
		shift
		for f in $@; do
			untrack "$f"
		done
		;;
	watching)
		find _* -name _WATCH -exec dirname '{}' ';'
		;;
	git)
		shift
		exec git "$@"
		;;
	ls)
		filelist | grep -v '_WATCH$'
		;;
	*)
		cat <<EOF
Usage: $0 [Action]

Actions:

  push      Install dotfiles onto the system
  pull      Pull all changes on the system into git
  diff      Show all changes that aren't pulled
  ls        List all dotfiles being tracked
  watching  List tracked directories

  track   [filename|directory]   Track a dotfile or directory
  untrack [filename|directory]   Untrack a file or directory
  diff    [filename]             Show changes in file
  git     [args for git]...      Use git
EOF
		;;
esac

exit 0
