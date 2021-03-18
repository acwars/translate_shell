#!/usr/bin/gawk -f

# Not all 4.x versions of gawk can handle @include without ".awk" extension
# But the build.awk script and the single build should support gawk 4.0+.
@include "include/commons.awk"
@include "include/utils.awk"
@include "include/languages.awk"
@include "metainfo.awk"

function init() {
    BuildPath            = "build/"
    Translate                = BuildPath Command
    TranslateAwk             = Translate ".awk"

    ManPath              = "man/"
    Man                  = ManPath Command ".1"
}

function man(    text) {
    gsub(/\$Version\$/, Version)
    gsub(/\$ReleaseDate\$/, ReleaseDate)

    return system("pandoc -s -f -t man -o " Man)
}

function readSqueezed(fileName, squeezed,    group, line, ret) {
    if (fileName ~ /\*$/) # glob simulation
        return readSqueezed(fileName ".awk", squeezed)

    ret = NULLSTR
    if (fileExists(fileName))
        while (getline line < fileName) {
            match(line, /^[[:space:]]*@include[[:space:]]*"(.*)"$/, group)
            if (RSTART) { # @include
                if (group[1] ~ /\.awk$/)
                    append(Includes, group[1])

                if (ret) ret = ret RS
                ret = ret readSqueezed(group[1], squeezed)
            } else if (!squeezed || line = squeeze(line)) { # effective LOC
                if (ret) ret = ret RS
                ret = ret line
            }
        }
    return ret
}

function build(target, type,    i, group, inline, line, temp) {
    # Default target: bash
    if (!target) target = "bash"

    ("mkdir -p " parameterize(BuildPath)) | getline

    if (target == "bash" || target == "zsh") {

        print "#!/usr/bin/env " target > Translate

        if (fileExists("DISCLAIMER")) {
            print "#" > Translate
            while (getline line < "DISCLAIMER")
                print "# " line > Translate
            print "#" > Translate
        }

        print "export TRANS_ENTRY=\"$0\"" > Translate
        print "if [[ ! $LANG =~ (UTF|utf)-?8$ ]]; then export LANG=en_US.UTF-8; fi" > Translate

        print "read -r -d '' TRANS_PROGRAM << 'EOF'" > Translate
        print readSqueezed(EntryPoint, TRUE) > Translate
        print "EOF" > Translate

        print "read -r -d '' TRANS_MANPAGE << 'EOF'" > Translate
        if (fileExists(Man))
            while (getline line < Man)
                print line > Translate
        print "EOF" > Translate
        print "export TRANS_MANPAGE" > Translate

        if (type == "release")
            print "export TRANS_BUILD=release" temp > Translate
        else {
            temp = getGitHead()
            if (temp)
                print "export TRANS_BUILD=git:" temp > Translate
        }

        print "gawk -f <(echo -E \"$TRANS_PROGRAM\") - \"$@\"" > Translate

        ("chmod +x " parameterize(Translate)) | getline

        # Rebuild EntryScript
        print "#!/bin/sh" > EntryScript
        print "export TRANS_DIR=`dirname $0`" > EntryScript
        print "gawk \\" > EntryScript
        for (i = 0; i < length(Includes) - 1; i++)
            print "-i \"${TRANS_DIR}/" Includes[i] "\" \\" > EntryScript
        print "-f \"${TRANS_DIR}/" Includes[i] "\" -- \"$@\"" > EntryScript
        ("chmod +x " parameterize(EntryScript)) | getline
        return 0

    } else if (target == "awk" || target == "gawk") {

        "uname -s" | getline temp
        print (temp == "Darwin" ?
               "#!/usr/bin/env gawk -f" : # macOS
               "#!/usr/bin/gawk -f") > TranslateAwk

        print readSqueezed(EntryPoint, TRUE) > TranslateAwk

        ("chmod +x " parameterize(TranslateAwk)) | getline
        return 0

    } else {

        w("[FAILED] Unknown target: " ansi("underline", target))
        w("         Supported targets: "                                \
          ansi("underline", "bash") ", "                                \
          ansi("underline", "zsh") ", "                                 \
          ansi("underline", "gawk"))
        return 1

    }
}

function clean() {
    ("rm -f " BuildPath Command "*") | getline
    return 0
}


function test() {
    return 0
}

BEGIN {
    init()

    pos = 0
    while (ARGV[++pos]) {
        # -target TARGET
        match(ARGV[pos], /^--?target(=(.*)?)?$/, group)
        if (RSTART) {
            target = tolower(group[2] ? group[2] : ARGV[++pos])
            continue
        }

        # -type TYPE
        match(ARGV[pos], /^--?type(=(.*)?)?$/, group)
        if (RSTART) {
            type = tolower(group[2] ? group[2] : ARGV[++pos])
            continue
        }

        # TASK
        match(ARGV[pos], /^[^\-]/, group)
        if (RSTART) {
            append(tasks, ARGV[pos])
            continue
        }
    }

    # Default task: build
    if (!anything(tasks)) tasks[0] = "build"

    for (i = 0; i < length(tasks); i++) {
        task = tasks[i]
        status = 0
        switch (task) {

        case "man":
            status = man()
            break

        case "doc":
            status = doc()
            break

        case "build":
            status = build(target, type)
            break

        case "clean":
            status = clean()
            break

        case "test":
            status = test()
            break

        default: # unknown task
            status = -1
        }

        if (status == 0) {
            d("[OK] Task " ansi("bold", task) " completed.")
        } else if (status < 0) {
            w("[FAILED] Unknown task: " ansi("bold", task))
            exit 1
        } else {
            w("[FAILED] Task " ansi("bold", task) " failed.")
            exit 1
        }
    }
}
