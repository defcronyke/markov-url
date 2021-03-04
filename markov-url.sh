#!/bin/bash

markov_url_deps() {
	which apt-get >/dev/null 2>&1
	IS_DEBIAN=$?

	which pacman >/dev/null 2>&1
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
		DEBIAN_DEPS="curl grep sed chromium recode html-xml-utils jq"
		DEBIAN_CMDS="curl grep sed chromium recode hxselect jq"

		HAS_ALL_DEBIAN_CMDS=0
		for i in ${DEBIAN_CMDS[@]}; do
			which "$i" >/dev/null 2>&1
			HAS_ALL_DEBIAN_CMDS=$?
			if [ $HAS_ALL_DEBIAN_CMDS -ne 0 ]; then
				break
			fi
		done

		if [ $HAS_ALL_DEBIAN_CMDS -ne 0 ]; then
			echo "Some dependencies are needed: $DEBIAN_DEPS"
			$SU_CMD apt-get update && sudo apt-get install $DEBIAN_DEPS
		fi
	elif [ $IS_ARCH -eq 0 ]; then
		which pacaur >/dev/null 2>&1
		HAS_PACAUR=$?

		which yay >/dev/null 2>&1
		HAS_YAY=$?

		if [ $HAS_PACAUR -ne 0 ] && [ $HAS_YAY -ne 0 ]; then
			echo "error: You need to install \"pacaur\" or \"yay\" first:"
			echo "error: https://aur.archlinux.org/packages/pacaur"
			echo "error: https://aur.archlinux.org/packages/yay"
			return 1
		fi

		if [ $HAS_PACAUR -eq 0 ]; then
			PAC_CMD="pacaur -Syy"
		elif [ $HAS_YAY -eq 0 ]; then
			PAC_CMD="yay -Syy"
		else
			echo "error: You need to install \"pacaur\" or \"yay\" first."
			return 2
		fi

		ARCH_DEPS="curl grep sed chromium recode html-xml-utils jq"
		ARCH_CMDS="curl grep sed chromium recode hxselect jq"

		HAS_ALL_ARCH_CMDS=0
		for i in ${ARCH_CMDS[@]}; do
			which "$i" >/dev/null 2>&1
			HAS_ALL_ARCH_CMDS=$?
			if [ $HAS_ALL_ARCH_CMDS -ne 0 ]; then
				break
			fi
		done

		if [ $HAS_ALL_ARCH_CMDS -ne 0 ]; then
			echo "Some dependencies are needed: $ARCH_DEPS"
			$PAC_CMD $ARCH_DEPS
		fi
	else
        OTHER_DEPS="curl grep sed chromium recode html-xml-utils jq"
        OTHER_CMDS="curl grep sed chromium recode hxselect jq"

        HAS_ALL_OTHER_CMDS=0
		for i in ${OTHER_CMDS[@]}; do
			which "$i" >/dev/null 2>&1
			HAS_ALL_OTHER_CMDS=$?
			if [ $HAS_ALL_OTHER_CMDS -ne 0 ]; then
				break
			fi
		done

		if [ $HAS_ALL_OTHER_CMDS -ne 0 ]; then
            echo "warning: Your distro isn't supported yet."
            echo "warning: It should still work if you have the following dependencies installed:"
            echo "warning: $OTHER_DEPS"
            echo "warning: You'll need to install those first. If you can find \"html-xml-utils\", \
try looking for the command named \"hxselect\", because that's what's needed from that package."
        fi
	fi
}

markov_url() {
	markov_url_deps $@

	WORDS=${WORDS:-"100"}
	NUM_URLS=${NUM_URLS:-15}

	REQ='{"query": "query trending($lineupSlug: String, $categorySlug: String, $pageSize: Int) {\n    allContentItems(lineupSlug: $lineupSlug, categorySlug: $categorySlug, pageSize: $pageSize) {\n        nodes {\n            sourceId\n            title\n            flag\n            href: url\n            imageLarge\n            trending {\n                numViewers\n                numViewersSRS\n            }\n        }\n    }\n}", "variables": "{\"lineupSlug\": \"trending-news\", \"categorySlug\": \"empty-category\", \"pageSize\": '$NUM_URLS'}"}'
	PRE_URL="aHR0cHM6Ly93d3cuY2JjLmNhL2dyYXBocWw="
	PRE_RES=$(curl -H 'Content-Type: application/json' -X POST -d "$REQ" -sL $(printf "$PRE_URL" | base64 -d))
	URLS=($(echo "$PRE_RES" | jq '.data.allContentItems.nodes | .[] | .href' | tr '\n' ' ' | tr -d '"'))
	URL_NUM=$(( $RANDOM % $NUM_URLS ))
	RAND_URL=${URLS[$URL_NUM]}

	URL=${URL:-$RAND_URL}

	# Allow args to be in either position.
	if [ $# -ge 1 ]; then
		# If arg is a number.
		if [ "$1" -eq "$1" ] 2>/dev/null; then
			WORDS="$1"
		else
			URL="$1"
		fi
	fi

	# Allow args to be in either position.
	if [ $# -ge 2 ]; then
		# If arg is a number.
		if [ "$1" -eq "$1" ] 2>/dev/null; then
			WORDS="$1"
			URL="$2"
		else
			URL="$1"
			WORDS="$2"
		fi
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
}

markov_url $@
