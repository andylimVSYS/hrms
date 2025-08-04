#!/bin/bash

# Load environment variables if .env file exists
if [ -f "/usr/src/app/.env" ]; then
    export $(cat /usr/src/app/.env | grep -v '^#' | xargs)
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

# Wait for database and redis to be ready
echo "Waiting for database and redis to be ready..."
while ! nc -z ${DB_HOST} ${DB_PORT}; do
    echo "Waiting for database at ${DB_HOST}:${DB_PORT}..."
    sleep 2
done

while ! nc -z ${REDIS_CACHE_HOST} ${REDIS_CACHE_PORT}; do
    echo "Waiting for redis at ${REDIS_CACHE_HOST}:${REDIS_CACHE_PORT}..."
    sleep 2
done

echo "Database and Redis are ready!"

# Check if bench already exists and is properly initialized
if [ -d "/home/frappe/frappe-bench/apps/frappe" ] && [ -d "/home/frappe/frappe-bench/sites/${SITE_NAME}" ]; then
    echo "Bench already exists and site is configured, starting..."
    cd /home/frappe/frappe-bench
    bench start
    exit 0
fi

# Ensure we're in the right directory
cd /home/frappe

# Set NODE environment if available
if [ -n "${NVM_DIR}" ] && [ -n "${NODE_VERSION_DEVELOP}" ]; then
    export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"
fi

# Remove any existing incomplete bench directory
if [ -d "/home/frappe/frappe-bench" ]; then
    echo "Removing incomplete bench directory..."
    rm -rf /home/frappe/frappe-bench
fi

echo "Creating new bench..."

# Initialize bench
bench init --skip-redis-config-generation frappe-bench

# Change to bench directory
cd frappe-bench

# Wait a moment for bench to be fully initialized
sleep 2

# Configure external services (only after bench is properly initialized)
echo "Configuring external database and Redis services..."
bench set-mariadb-host ${DB_HOST}
bench set-redis-cache-host redis://${REDIS_CACHE_HOST}:${REDIS_CACHE_PORT}
bench set-redis-queue-host redis://${REDIS_QUEUE_HOST}:${REDIS_QUEUE_PORT}
bench set-redis-socketio-host redis://${REDIS_SOCKETIO_HOST}:${REDIS_SOCKETIO_PORT}

# Remove redis, watch from Procfile since we use external services
if [ -f "./Procfile" ]; then
    sed -i '/redis/d' ./Procfile
    sed -i '/watch/d' ./Procfile
fi

# Install apps only if they don't exist
if [ ! -d "apps/erpnext" ]; then
    echo "Installing ERPNext..."
    bench get-app erpnext
fi

if [ ! -d "apps/hrms" ]; then
    echo "Installing HRMS using bench..."
    bench get-app hrms
fi

# Create site only if it doesn't exist
if [ ! -d "sites/${SITE_NAME}" ]; then
    echo "Creating site ${SITE_NAME}..."
    bench new-site ${SITE_NAME} \
    --force \
    --mariadb-root-password ${DB_ROOT_PASSWORD} \
    --admin-password ${ADMIN_PASSWORD} \
    --no-mariadb-socket

    echo "Installing HRMS app on site..."
    # Check if HRMS app is properly installed before trying to install it on site
    if [ -d "apps/hrms" ] && [ -f "apps/hrms/hrms/__init__.py" ]; then
        bench --site ${SITE_NAME} install-app hrms
        bench --site ${SITE_NAME} set-config developer_mode ${DEVELOPER_MODE}
        bench --site ${SITE_NAME} enable-scheduler
        bench --site ${SITE_NAME} clear-cache
        bench use ${SITE_NAME}
    else
        echo "ERROR: HRMS app not properly installed, skipping site installation"
        echo "Available apps:"
        ls -la apps/
    fi
else
    echo "Site ${SITE_NAME} already exists, using existing site..."
    bench use ${SITE_NAME}
fi

echo "Starting bench..."
echo "=== Final Status Check ==="
echo "Installed apps:"
bench --site ${SITE_NAME} list-apps || echo "Could not list apps"
echo "Site: ${SITE_NAME}"
echo "Available at: http://localhost:8000"
echo "=========================="
bench start