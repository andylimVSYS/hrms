#!/bin/bash

# Load environment variables if .env file exists
if [ -f "/home/frappe/.env" ]; then
    export $(cat /home/frappe/.env | grep -v '^#' | xargs)
fi

# Set default values if not provided
DB_HOST=${DB_HOST:-mariadb}
DB_PORT=${DB_PORT:-3306}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-123}
REDIS_CACHE_HOST=${REDIS_CACHE_HOST:-redis}
REDIS_CACHE_PORT=${REDIS_CACHE_PORT:-6379}
REDIS_QUEUE_HOST=${REDIS_QUEUE_HOST:-redis}
REDIS_QUEUE_PORT=${REDIS_QUEUE_PORT:-6379}
REDIS_SOCKETIO_HOST=${REDIS_SOCKETIO_HOST:-redis}
REDIS_SOCKETIO_PORT=${REDIS_SOCKETIO_PORT:-6379}
SITE_NAME=${SITE_NAME:-hrms.localhost}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
DEVELOPER_MODE=${DEVELOPER_MODE:-1}

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, skipping init"
    cd frappe-bench
    bench start
else
    echo "Creating new bench..."
fi

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

bench init --skip-redis-config-generation frappe-bench

cd frappe-bench

# Use external database and redis instances
bench set-mariadb-host ${DB_HOST}
bench set-redis-cache-host redis://${REDIS_CACHE_HOST}:${REDIS_CACHE_PORT}
bench set-redis-queue-host redis://${REDIS_QUEUE_HOST}:${REDIS_QUEUE_PORT}
bench set-redis-socketio-host redis://${REDIS_SOCKETIO_HOST}:${REDIS_SOCKETIO_PORT}

# Remove redis, watch from Procfile
sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

bench get-app erpnext

# Get HRMS app from local copy
bench get-app /home/frappe/hrms-app

bench new-site ${SITE_NAME} \
--force \
--mariadb-root-password ${DB_ROOT_PASSWORD} \
--admin-password ${ADMIN_PASSWORD} \
--no-mariadb-socket

bench --site ${SITE_NAME} install-app hrms
bench --site ${SITE_NAME} set-config developer_mode ${DEVELOPER_MODE}
bench --site ${SITE_NAME} enable-scheduler
bench --site ${SITE_NAME} clear-cache
bench use ${SITE_NAME}

bench start