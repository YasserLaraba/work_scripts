#!/bin/bash

# Usage:
# find-txt [--no-grep-opts] [grep-options] <text> [--no-find-opts] [find-options] <directory>
# Defaults:
#   grep: -rin --color=auto
#   find: -iname
# Example:
#   find-txt -i "cluster" -maxdepth 2 "projects"
#   find-txt --no-grep-opts "cluster" --no-find-opts "projects"

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 [--no-grep-opts] [grep-options] <text> [--no-find-opts] [find-options] <directory>"
    echo "Defaults:"
    echo "  grep: -rin --color=auto"
    echo "  find: -iname"
    echo "Flags to remove all options:"
    echo "  --no-grep-opts     Remove all grep options"
    echo "  --no-find-opts     Remove all find options"
    echo "Example:"
    echo "  $0 -i <text> -maxdepth 2 <directory>"
    echo "  $0 --no-grep-opts <text> --no-find-opts <directory>"
    exit 1
fi

args=("$@")
last_index=$(($# - 1))
text=""
dir="${args[$last_index]}"
user_grep_opts=()
user_find_opts=()

no_grep_opts=false
no_find_opts=false

parsed_text=false

# Process arguments to separate flags, options, text, and directory
for ((i=0; i<=$last_index; i++)); do
    arg="${args[$i]}"

    if [[ "$arg" == "--no-grep-opts" ]]; then
        no_grep_opts=true
        continue
    fi
    if [[ "$arg" == "--no-find-opts" ]]; then
        no_find_opts=true
        continue
    fi

    # If text not found yet, find first non-option as text
    if ! $parsed_text; then
        if [[ "$arg" != -* ]]; then
            text="$arg"
            parsed_text=true
        else
            # Before text, treat as grep options if not disabled
            if ! $no_grep_opts; then
                user_grep_opts+=("$arg")
            fi
        fi
    else
        # After text: treat as find options if not disabled, except last arg (directory)
        if (( i < last_index )); then
            if ! $no_find_opts; then
                user_find_opts+=("$arg")
            fi
        fi
    fi
done

dir="${args[$last_index]}"

# Set defaults if not disabled and no user options present
default_grep_opts=(-rin --color=auto)
default_find_opts=(-iname)

if $no_grep_opts; then
    grep_opts=()
    display_grep_opts=()
else
    if [ "${#user_grep_opts[@]}" -eq 0 ]; then
        grep_opts=("${default_grep_opts[@]}")
        display_grep_opts=("${default_grep_opts[@]}")
    else
        grep_opts=("${user_grep_opts[@]}")
        display_grep_opts=("${user_grep_opts[@]}" "${default_grep_opts[@]}")
    fi
fi

if $no_find_opts; then
    find_opts=()
    display_find_opts=()
else
    if [ "${#user_find_opts[@]}" -eq 0 ]; then
        find_opts=("${default_find_opts[@]}")
        display_find_opts=("${default_find_opts[@]}")
    else
        find_opts=("${user_find_opts[@]}")
        display_find_opts=("${user_find_opts[@]}" "${default_find_opts[@]}")
    fi
fi

# Verify mandatory parameters
if [ -z "$text" ] || [ -z "$dir" ]; then
    echo "Usage: $0 [--no-grep-opts] [grep-options] <text> [--no-find-opts] [find-options] <directory>"
    exit 1
fi

echo "Running grep with options: ${display_grep_opts[*]}"
echo "Search text: $text"
echo "Running find with options: ${display_find_opts[*]}"
echo "Directory: $dir"
echo

# Run grep with options and preserve color output, skip if no options and no args
echo
echo "#############################"
echo "Matches inside files in $dir:"
if [[ ${#grep_opts[@]} -eq 0 ]]; then
    echo
    # Run simple grep without any options (only mandatory arguments)
    if grep "$text" "$dir" 2>/dev/null; then
        echo
    else
        echo
        echo "No matches found inside file contents in $dir."
    fi
else
    if grep "${grep_opts[@]}" "$text" "$dir" 2>/dev/null; then
        echo
    else
        echo
        echo "No matches found inside file contents in $dir."
    fi
fi

# Run find with options and -iname pattern if any, otherwise basic find with pattern
echo
echo "#################################################"
echo "Matches in filenames and directory names in $dir:"
if [[ ${#find_opts[@]} -eq 0 ]]; then
    name_results=$(find "$dir" -name "*$text*" 2>/dev/null)
else
    name_results=$(find "$dir" "${find_opts[@]}" "*$text*" 2>/dev/null)
fi

if [ -n "$name_results" ]; then
    echo
    echo "$name_results"
else
    echo
    echo "No matches found in filenames or directory names in $dir."
fi
