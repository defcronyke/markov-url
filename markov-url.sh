#!/bin/bash

markov_url() {
    URL=${URL:-"$(printf "aHR0cHM6Ly93d3cuY2JjLmNhL25ld3MvdGVjaG5vbG9neS9hcmNoZW9sb2dpc3RzLWNlcmVtb25pYWwtY2hhcmlvdC1wb21wZWlpLTEuNTkzMTcxMg==" | base64 -d)"}
    WORDS=${WORDS:-"100"}

    if [ $# -ge 1 ]; then
        URL="$1"
    fi

    if [ $# -ge 2 ]; then
        WORDS="$2"
    fi

    which apt-get 2>&1 >/dev/null
    IS_DEBIAN=$?

    which pacman 2>&1 >/dev/null
    IS_ARCH=$?

    cat /etc/group | grep 'sudo' | grep "$USER" 1>/dev/null
    IS_SUDOER=$?
    if [ $? -ne 0 ]; then
        cat /etc/group | grep 'wheel' | grep "$USER" 1>/dev/null
        IS_SUDOER=$?
    fi

    SU_CMD="su - -c"

    if [ $IS_SUDOER -eq 0 ]; then
        SU_CMD="sudo"
    fi

    if [ $IS_DEBIAN -eq 0 ]; then
        DEBIAN_DEPS="curl grep sed chromium html-xml-utils recode"
        DEBIAN_CMDS="curl grep sed chromium hxselect recode"

        HAS_ALL_CMDS=0
        for i in ${DEBIAN_CMDS[@]}; do
            which "$i" 2>&1 >/dev/null
            HAS_ALL_CMDS=$?
            if [ $HAS_ALL_CMDS -ne 0 ]; then
                break
            fi
        done

        if [ $HAS_ALL_CMDS -ne 0 ]; then
            $SU_CMD apt-get update && sudo apt-get install -y $DEBIAN_DEPS
        fi
    else
        echo "warning: Your distro isn't supported yet."
        return 1
    fi
        
    PAGE_FILTERED=$(PAGE=$(curl -sL "$URL" | sed -n '/^.*<body/,/^.*<\/body>/{p;/^.*<\/body>/q}'); \
        echo "$PAGE" | (hxselect -s ' ' -ic '.detailHeadline, .story h2' && echo "$PAGE" | \
        hxselect -s ' ' -ic '.story p') | sed 's@\—@@g' | sed 's@ @ @g' | \
        recode -qf html..utf-8 | recode -qf utf-8..ascii | \
        sed -E 's@(['"'"'"`])@\\\1@g' | \
        sed -E 's@</*.+>@@g')

    URI_STR="https://defcronyke.github.io/markov-chain?words=${WORDS}&in="

    MAX_URI_LEN=4096

    PAGE_FILTERED_LEN=$(printf "$PAGE_FILTERED" | wc -m)

    QUERY_IN_LEN=$PAGE_FILTERED_LEN

    URI_LEN=$(printf "$URI_STR" | wc -m)

    if [ $(( URI_LEN + PAGE_FILTERED_LEN )) -gt $MAX_URI_LEN ]; then
        PAGE_FILTERED=${PAGE_FILTERED:0:$(( MAX_URI_LEN - URI_LEN ))}
    fi
    
    FINAL_URI="${URI_STR}${PAGE_FILTERED}"

    chromium --headless --disable-gpu --dump-dom \
        "$FINAL_URI" 2>/dev/null | \
        grep "<body>" | sed 's/<body>//' | sed 's@\\@@g' | \
        recode -qf html..ascii

    # echo -e "\n\n=========================================\n"
    
    # PAGE=$(curl -sL "$URL" | sed -n '/^.*<body/,/^.*<\/body>/{p;/^.*<\/body>/q}'); \
    #     echo "$PAGE" | (hxselect -s ' ' -ic '.detailHeadline, .story h2' && echo "$PAGE" | \
    #     hxselect -s ' ' -ic '.story p') | sed 's@\—@@g' | sed 's@ @ @g' | \
    #     recode -qf html..utf-8 | recode -qf utf-8..ascii

    # echo -e "\n\n=========================================\n"

    # PAGE=$(curl -sL "$URL" | sed -n '/^.*<body/,/^.*<\/body>/{p;/^.*<\/body>/q}'); \
    #     echo "$PAGE" | (hxselect -s ' ' -ic '.detailHeadline, .story h2' && echo "$PAGE" | \
    #     hxselect -s ' ' -ic '.story p') | sed 's@\—@@g' | sed 's@ @ @g'

    # echo -e "\n\n=========================================\n"
}

markov_url $@
