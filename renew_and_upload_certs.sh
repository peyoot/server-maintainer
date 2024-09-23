#!/bin/bash
ACME_SH="/home/rtu/.acme.sh/acme.sh"
DOMAIN_LIST="./domain.list"
CERT_LOCAL_PATH="/home/rtu/.acme.sh"
LOG_FILE="./renew_certs.log"
# Read every line of config file and handle it
mapfile -t lines < "$DOMAIN_LIST"

for line in "${lines[@]}"; do
    IFS='@ ' read -r DOMAIN REMOTE_USER REMOTE_HOST REMOTE_PATH <<< "$line"
    if [[ $REMOTE_HOST =~ : ]]; then
        REMOTE_PORT="${REMOTE_HOST##*:}"
        REMOTE_HOST="${REMOTE_HOST%:*}"
    else
        REMOTE_PORT=22
    fi

    # renew certification
    $ACME_SH --renew --force -d $DOMAIN

    # check if renew success
    if [ $? -eq 0 ]; then
        echo "Certificate renewed for $DOMAIN. Uploading to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH..."
        # certifiction name
        CERT_FILE="${DOMAIN}.cer"
        KEY_FILE="${DOMAIN}.key"
        FULLCHAIN_FILE="fullchain.cer"

        if (ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "if [ ! -d /home/${REMOTE_USER}/certs/${DOMAIN}_ecc ]; then mkdir -p /home/${REMOTE_USER}/certs/${DOMAIN}_ecc; fi" ) ; then
            echo " now scp ${CERT_LOCAL_PATH}/${DOMAIN}_ecc/${CERT_FILE} to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${CERT_FILE}"
            scp  -o ConnectTimeout=300 -P $REMOTE_PORT "${CERT_LOCAL_PATH}/${DOMAIN}_ecc/${CERT_FILE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${DOMAIN}_ecc/${CERT_FILE}"
            scp  -o ConnectTimeout=300 -P $REMOTE_PORT "${CERT_LOCAL_PATH}/${DOMAIN}_ecc/${KEY_FILE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${DOMAIN}_ecc/${KEY_FILE}"
            scp  -o ConnectTimeout=300 -P $REMOTE_PORT "${CERT_LOCAL_PATH}/${DOMAIN}_ecc/${FULLCHAIN_FILE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${DOMAIN}_ecc/${FULLCHAIN_FILE}"
        else
            echo "can't access remote host: $REMOTE_HOST. Domain certs failed to update to remote server" 
        fi
        if (ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "sudo systemctl restart nginx") ; then
            echo "Successfully restarted nginx on ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}."
            echo "Upload and restart completed for $DOMAIN." >> "$LOG_FILE"
        else
            echo "Failed to restart nginx on ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}."
            echo "Failed to restart nginx for $DOMAIN." >> "$LOG_FILE"
        fi
    else
        echo "Failed to renew certificate for $DOMAIN." >> "$LOG_FILE"
    fi

done

