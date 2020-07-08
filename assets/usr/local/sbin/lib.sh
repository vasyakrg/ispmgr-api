#!/bin/bash

function fatal() {
    echo "FATAL! $1"
    exit 1
}

function good() {
    echo "GOOD! $1"
    exit 0
}

function check_env() {

    local ENVS=(DNS_SERVER DNS_LOGIN DNS_PASSWORD DOMAIN_NAME DNS_VALUE_TYPE DNS_VALUE DNS_SETNAME DNS_TTL)
    local ENV=""

    for ENV in "${ENVS[@]}"; do
        # echo $ENV
        if [[ -z "${!ENV+x}" ]]; then
            echo "not set $ENV env"
        fi
    done
}

function add() {
    case "${DNS_VALUE_TYPE}" in
        cname|CNAME)
            curl -ks "https://${DNS_SERVER}/ispmgr?authinfo=${DNS_LOGIN}:${DNS_PASSWORD}&out=sjson&sok=ok&func=domain.record.edit&plid=${DOMAIN_NAME}&ip=&name=${DNS_SETNAME}&domain=${DNS_VALUE}&rtype=cname&ttl=${DNS_TTL}"
        ;;
        a|A)
            curl -ks "https://${DNS_SERVER}/ispmgr?authinfo=${DNS_LOGIN}:${DNS_PASSWORD}&out=sjson&sok=ok&func=domain.record.edit&plid=${DOMAIN_NAME}&name=${DNS_SETNAME}&ip=${DNS_VALUE}&rtype=a&ttl=${DNS_TTL}"
        ;;
        * ) echo "403" ;;
    esac

}

function delete() {
    case ${DNS_VALUE_TYPE} in
        cname|CNAME)
            curl -ks "https://${DNS_SERVER}/ispmgr?authinfo=${DNS_LOGIN}:${DNS_PASSWORD}&out=sjson&sok=ok&func=domain.record.delete&plid=${DOMAIN_NAME}&elid=${DNS_SETNAME}.${DOMAIN_NAME}.%20CNAME%20%20${DNS_VALUE}"
        ;;
        a|A)
            curl -ks "https://${DNS_SERVER}/ispmgr?authinfo=${DNS_LOGIN}:${DNS_PASSWORD}&out=sjson&sok=ok&func=domain.record.delete&plid=${DOMAIN_NAME}&elid=${DNS_SETNAME}.${DOMAIN_NAME}.%20A%20%20${DNS_VALUE}"
        ;;
        *) echo "403" ;;
    esac
}

function create_record() {
    result=$(add)

    if [[ $result == "403" ]]; then
        fatal "Error dns value type. Only of <a> or <cname>"
    fi

    if [[ ! $(echo $result | jq -r '.doc.error') == 'null' ]]; then
        [[ $(echo $result | jq -r '.doc.error.group."$"') == "__object__ with '__value__' already exists" ]] && {
            good "$(echo $result | jq -r '.doc.error.msg."$"')"
        } || {
            fatal "$(echo $result | jq -r '.doc.error.msg."$"')"
        }
    else good "Record created"
    fi
}

function delete_record() {
    result=$(delete)

    if [[ $result == "403" ]]; then
        fatal "Error dns value type. Only of <a> or <cname>"
    fi

    # echo $result | jq -r '.'

    [[ ! $(echo $result | jq -r '.doc.error') == 'null' ]] && {
        fatal "$(echo $result | jq -r '.doc.error.msg."$"')"
    } || good "Record deleted"
}
