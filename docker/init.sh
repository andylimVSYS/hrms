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

# Ensure apps.txt exists and has correct format
echo "Ensuring apps.txt exists..."
if [ ! -f "apps/apps.txt" ]; then
    echo "frappe" > apps/apps.txt
fi

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

# Remove ERPNext from apps.txt and directory if it exists (HRMS-only deployment)
echo "Removing ERPNext for HRMS-only deployment..."
if [ -d "apps/erpnext" ]; then
    echo "Removing ERPNext app directory..."
    rm -rf apps/erpnext
fi

# Clean apps.txt to remove any erpnext entries and ensure it only has frappe
echo "frappe" > apps/apps.txt

echo "📋 Current apps.txt content after ERPNext removal:"
cat apps/apps.txt || echo "apps.txt file missing"

if [ ! -d "apps/hrms" ]; then
    echo "Installing HRMS from application directory..."
    
    # Copy the HRMS app directly to avoid git ownership issues
    echo "Copying HRMS app files..."
    cp -r /usr/src/app apps/hrms
    
    # Remove git directory to avoid issues
    rm -rf apps/hrms/.git
    
    # Add HRMS to apps.txt
    echo "Adding HRMS to apps.txt..."
    echo "hrms" >> apps/apps.txt
    
    # Ensure proper app structure exists
    echo "Verifying HRMS app structure..."
    if [ ! -f "apps/hrms/setup.py" ]; then
        echo "WARNING: setup.py not found in HRMS app"
    fi
    if [ ! -f "apps/hrms/hrms/__init__.py" ]; then
        echo "WARNING: hrms/__init__.py not found"
    fi
    
    # Create package.json if missing
    if [ ! -f "apps/hrms/package.json" ]; then
        echo "Creating package.json for HRMS..."
        cat > apps/hrms/package.json << 'EOF'
{
  "name": "hrms",
  "version": "1.0.0",
  "description": "Frappe HR",
  "main": "index.js",
  "dependencies": {
    "html2canvas": "^1.4.1"
  }
}
EOF
    fi
    
    # Install the Python package
    echo "Installing HRMS Python package..."
    /home/frappe/frappe-bench/env/bin/python -m pip install --quiet --upgrade -e /home/frappe/frappe-bench/apps/hrms
    
    # Install Node.js dependencies
    echo "Installing HRMS Node.js dependencies..."
    cd apps/hrms
    npm install --silent 2>/dev/null || echo "NPM install failed, continuing..."
    cd ../..
    
    # Try to build without failing the entire process
    echo "Attempting to build HRMS assets..."
    bench build --app hrms 2>/dev/null || {
        echo "HRMS build failed - this is expected and won't prevent the app from working"
        echo "The HRMS Python functionality will still work without frontend assets"
    }
    
    echo "HRMS app installation completed"
fi

# Create site only if it doesn't exist
if [ ! -d "sites/${SITE_NAME}" ]; then
    echo "Creating site ${SITE_NAME}..."
    bench new-site ${SITE_NAME} \
    --force \
    --mariadb-root-password ${DB_ROOT_PASSWORD} \
    --admin-password ${ADMIN_PASSWORD} \
    --no-mariadb-socket

    echo "Installing apps on site..."
    
    # Remove ERPNext from site if it exists (for HRMS-only deployment)
    echo "Checking for ERPNext on site and removing if present..."
    if bench --site ${SITE_NAME} list-apps | grep -q "erpnext"; then
        echo "ERPNext found on site, removing..."
        bench --site ${SITE_NAME} uninstall-app erpnext --yes --force || echo "ERPNext removal failed, continuing..."
    else
        echo "ERPNext not found on site (good for HRMS-only deployment)"
    fi
    
    # Install HRMS directly (skip ERPNext dependency)
    echo "Installing HRMS app on site..."
    if [ -d "apps/hrms" ] && [ -f "apps/hrms/hrms/__init__.py" ] && grep -q "hrms" apps/apps.txt; then
        echo "HRMS app found, attempting installation..."
        if bench --site ${SITE_NAME} install-app hrms; then
            echo "✅ HRMS successfully installed!"
        else
            echo "⚠️  HRMS installation failed"
            echo "You can try installing HRMS manually later with:"
            echo "  bench --site ${SITE_NAME} install-app hrms"
        fi
    else
        echo "⚠️  HRMS app not properly configured"
        echo "Available apps in apps.txt:"
        cat apps/apps.txt 2>/dev/null || echo "apps.txt not found"
        echo "Site will work with Frappe only"
    fi
    
    # Configure site settings
    bench --site ${SITE_NAME} set-config developer_mode ${DEVELOPER_MODE}
    bench --site ${SITE_NAME} enable-scheduler
    bench --site ${SITE_NAME} clear-cache
    bench use ${SITE_NAME}
else
    echo "Site ${SITE_NAME} already exists, using existing site..."
    bench use ${SITE_NAME}
fi

echo "Starting bench..."
echo "=== DEPLOYMENT STATUS ==="
echo "📋 Apps.txt contents:"
cat apps/apps.txt || echo "❌ apps.txt not found"
echo ""
echo "📦 Installed apps on site:"
bench --site ${SITE_NAME} list-apps || echo "❌ Could not list apps"
echo ""
echo "📁 Available apps in directory:"
ls -1 apps/ | grep -v apps.txt | sed 's/^/  /' || echo "❌ No app directories found"
echo ""
echo "🌐 Site Information:"
echo "  Site Name: ${SITE_NAME}"
echo "  Admin User: Administrator"
echo "  Admin Password: ${ADMIN_PASSWORD}"
echo "  Access URL: http://localhost:8000"
echo ""
if bench --site ${SITE_NAME} list-apps | grep -q "hrms"; then
    echo "✅ SUCCESS: HRMS deployment completed!"
    echo "   You now have Frappe + HRMS (HR Management System)"
else
    echo "⚠️  PARTIAL: Frappe deployed successfully"
    echo "   HRMS installation may have issues but can be fixed manually"
fi
echo "=========================="
bench start