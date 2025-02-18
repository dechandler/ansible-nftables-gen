#!/bin/sh

BASE_DIR="/etc/nftables-gen"

CONF="${BASE_DIR}/assembled.conf"

HOOKS_DIR="${BASE_DIR}/hooks"
DEFS_DIR="${BASE_DIR}/defs"

function generate () {

    echo '#!/usr/sbin/nft -f' > $CONF
    chmod 600 $CONF
    echo 'flush ruleset' >> $CONF

    cat ${DEFS_DIR}/*.conf >> $CONF


    for FAMILY in inet ip ip6 arp bridge netdev; do

        local FAMILY_EXISTS=`find ${HOOKS_DIR}/${FAMILY} -type f -name "*.conf" 2>/dev/null`
        if [[ -z $FAMILY_EXISTS ]]; then
            continue
        fi

        echo "table ${FAMILY} global {" >> $CONF

        for CHAIN_TYPE in filter nat route; do
            for HOOK in ingress prerouting forward input output postrouting egress; do
                HOOK_DIR="${HOOKS_DIR}/${FAMILY}/${CHAIN_TYPE}-${HOOK}.d"
                if [[ -d $HOOK_DIR ]]; then
                    local HOOK_EXISTS=`find "${HOOK_DIR}" -type f -name "*.conf" 2>/dev/null`
                    if [[ -z $HOOK_EXISTS ]]; then
                        continue
                    fi

                    case "${FAMILY} ${HOOK}" in
                        "bridge output") PRIORITY="out" ;;
                        "* prerouting")  PRIORITY="dstnat" ;;
                        "* postrouting") PRIORITY="srcnat" ;;
                        *)               PRIORITY="filter" ;;
                    esac

                    CHAIN_NAME=`echo "${CHAIN_TYPE}_${HOOK}" | tr '[:lower:]' '[:upper:]'`
                    echo "  chain ${CHAIN_NAME} {" >> $CONF
                    echo "    type ${CHAIN_TYPE} hook ${HOOK} priority ${PRIORITY}; policy accept;" >> $CONF
                    find ${HOOK_DIR} -name '*.conf' | sort | while read FPATH; do
                        sed 's/^/    /' $FPATH >> $CONF
                        echo '' >> $CONF
                    done
                    echo "  }" >> $CONF

                fi

            done
        done

        echo '}' >> $CONF
        echo '' >> $CONF

    done

}


case $1 in
    start)
        generate
        /sbin/nft -f /etc/nftables-gen/assembled.conf
    ;;
    stop)
        /sbin/nft flush ruleset
    ;;
    gen*)
        generate
    ;;
esac
