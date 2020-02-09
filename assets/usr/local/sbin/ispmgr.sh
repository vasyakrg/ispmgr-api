#!/bin/bash
source lib.sh

check_env

COM=$1

case $COM in
    create)
        echo "Create record ${DNS_SETNAME}.${DOMAIN_NAME} with IP:${DNS_SETIP}"
        create_record
    ;;
    delete)
        echo "Detele record ${DNS_SETNAME}.${DOMAIN_NAME} with IP:${DNS_SETIP}"
        delete_record
    ;;
    *)
        fatal "Use script with command <create> or <delete>"
    ;;
esac
