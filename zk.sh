#!/bin/bash

set -eo pipefail

function usage {
    echo "Usage: zk {new,search,link,pull,push,help}"
    echo ""
    echo "Create zettels"
    echo "  zk new TITLE [tag1,tag2]"
    echo ""
    echo "Search your kasten"
    echo "  zk search [tag]"
    echo ""
    echo "Link zettels"
    echo "  zk link [src] [dst]"
    echo ""
    echo "Push changes"
    echo "  zk push"
    echo ""
    echo "Pull changes"
    echo "  zk pull"
    echo ""
}

function commit {
    local mode=$1
    local file=$2

    cd $ZETTELKASTEN_PATH &>/dev/null

    git add $file
    git commit -m "$mode $file" &>/dev/null

    cd - &>/dev/null
}

function push {
    cd $ZETTELKASTEN_PATH &>/dev/null

    git push origin master

    cd - &>/dev/null
}

function pull {
    cd $ZETTELKASTEN_PATH &>/dev/null

    git pull origin master

    cd - &>/dev/null
}

function link {
    local src=$1
    local dst=$2
    local files

    if [ -z "$src" ]; then
        src=$(grep "title:" $ZETTELKASTEN_PATH/*.md | awk 'BEGIN {FS="/"};{print $5}' | fzf -d ":" --preview "cat $ZETTELKASTEN_PATH/{1}" --preview-window=up:40%)
        if [ -z "$src" ]; then
            exit 1
        fi
        src=$(echo $src | awk 'BEGIN {FS=":"};{print $1}')
    fi

    if [ -z "$dst" ]; then
        dst=$(grep "title:" $ZETTELKASTEN_PATH/*.md | awk 'BEGIN {FS="/"};{print $5}' | fzf -d ":" --preview "cat $ZETTELKASTEN_PATH/{1}" --preview-window=up:40%)
        if [ -z "$dst" ]; then
            exit 1
        fi
        dst=$(echo $dst | awk 'BEGIN {FS=":"};{print $1}')
    fi

    local src_title=$(grep "title:" $ZETTELKASTEN_PATH/$src | cut -d " " -f2-)
    local dst_title=$(grep "title:" $ZETTELKASTEN_PATH/$dst | cut -d " " -f2-)

    echo "* [$dst_title]($dst)" >> $ZETTELKASTEN_PATH/$src
    echo "* [$src_title]($src)" >> $ZETTELKASTEN_PATH/$dst

    commit "link" $ZETTELKASTEN_PATH/$src
    commit "link" $ZETTELKASTEN_PATH/$dst
}

function search {
    local tag=$1
    local files

    if [ ! -z "$tag" ]; then
        files=$(grep -l "$tag" $ZETTELKASTEN_PATH/*.md)
    else
        files=$(ls -1 $ZETTELKASTEN_PATH/*.md)
    fi

    files=$(printf "$files" | xargs -r grep "title:" --with-filename | awk 'BEGIN {FS="/"};{print $5}')
    local filename=$(printf "$files" | fzf -d ":" --preview "cat $ZETTELKASTEN_PATH/{1}" --preview-window=up:40%)

    if [ -z "$filename" ]; then
        exit 1
    fi

    filename=$(echo $filename | awk 'BEGIN {FS=":"};{print $1}')

    $EDITOR "$ZETTELKASTEN_PATH/$filename"

    commit "edit" $filename
}

function new {
    local title=$1
    local tags=$2
    local date=$(date +%Y-%m-%d)
    local timestamp=$(date +%Y%m%d%H%M%S)
    local tmpfile=$(mktemp)
    local filename="$timestamp.md"
    local zettel="$ZETTELKASTEN_PATH/$filename"

    echo "---" > $tmpfile
    echo "title: $title" >> $tmpfile
    echo "date: $date" >> $tmpfile

    if [ ! -z "$tags" ]; then
        echo "tags:" >> $tmpfile
        while IFS="," read -ra tag; do
            for i in "${tag[@]}"; do
                echo "  - $i" >> $tmpfile
            done
        done <<< "$tags"
    fi

    echo "---" >> $tmpfile

    $EDITOR $tmpfile

    if [ $? != 0 ]; then
        echo "Not saving zettel"
        exit 1
    fi

    cp $tmpfile $zettel
    commit "add" $filename
}

function main {
    local cmd=$1

    if [ $cmd == "help" ]; then
        usage
        exit 0
    fi

    if [ -z $ZETTELKASTEN_PATH ]; then
        echo "Set ZETTELKASTEN_PATH environment variable"
        exit 1
    fi

    case $cmd in
        "new")
            new $2 $3
            ;;
        "search")
            search $2
            ;;
        "link")
            link $2 $3
            ;;
        "push")
            push
            ;;
        "pull")
            pull
            ;;
        *)
            echo "Unknown command"
            exit 1
    esac
}

main $@
