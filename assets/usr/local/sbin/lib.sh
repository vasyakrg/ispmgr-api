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

    local ENVS=(DNS_SERVER DNS_LOGIN DNS_PASSWORD DOMAIN_NAME DNS_SETIP DNS_SETNAME)
    local ENV=""

    for ENV in "${ENVS[@]}"; do
        # echo $ENV
        if [[ -z "${!ENV+x}" ]]; then
            echo "not set $ENV env"
        fi
    done
}

function add() {
    curl -ks "https://${DNS_SERVER}/ispmgr?authinfo=${DNS_LOGIN}:${DNS_PASSWORD}&out=sjson&sok=ok&func=domain.record.edit&plid=${DOMAIN_NAME}&ip=${DNS_SETIP}&name=${DNS_SETNAME}&rtype=a&ttl=3600"
}

function delete() {
    curl -ks "https://${DNS_SERVER}/ispmgr?authinfo=${DNS_LOGIN}:${DNS_PASSWORD}&out=sjson&sok=ok&func=domain.record.delete&plid=${DOMAIN_NAME}&elid=${DNS_SETNAME}.${DOMAIN_NAME}.%20A%20%20${DNS_SETIP}"
}

function create_record() {
    result=$(add)
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
    [[ ! $(echo $result | jq -r '.doc.error') == 'null' ]] && {
        fatal "$(echo $result | jq -r '.doc.error.msg."$"')"
    } || good "Record deleted"

}
