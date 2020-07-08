#!/bin/bash
source lib.sh

check_env

COM=$1

case $COM in
    create)
        echo "Create ${DNS_VALUE_TYPE}-record ${DNS_SETNAME}.${DOMAIN_NAME} with VALUE=${DNS_VALUE}"
        create_record
    ;;
    delete)
        echo "Detele ${DNS_VALUE_TYPE}-record ${DNS_SETNAME}.${DOMAIN_NAME} with VALUE=${DNS_VALUE}"
        delete_record
    ;;
    *)
        fatal "Use script with command <create> or <delete>"
    ;;
esac
