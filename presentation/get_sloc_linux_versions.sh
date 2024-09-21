#!/bin/bash

if [[ $# -ne 3 ]]; then
    echo "[*] Usage: ./program <linux-src> <starting-git-tag> <tag-sloc-csv>"
    exit 1
fi

linux_src=$1
start_tag=$2
tag_sloc_csv=$3
tag_sloc_csv="$(pwd)/$tag_sloc_csv"

touch $tag_sloc_csv

declare -a tags_array

pushd $linux_src > /dev/null

git clean -dfx
git reset --hard

while read -r tag; do
    if [[ "$tag" == "$start_tag" || "$tag" > "$start_tag" ]]; then
        echo "$tag"
        tags_array+=("$tag")
    fi
done < <(git tag --sort=v:refname | grep -E '^v[0-9]+\.[0-9]+$')

for tag in "${tags_array[@]}"; do
    git checkout $tag
    cloc . > cloc_result.txt 2>&1
    sloc=$(grep "SUM" cloc_result.txt | awk -F' ' '{print $5}')
    echo "$tag,$sloc" >> $tag_sloc_csv
done

popd > /dev/null
