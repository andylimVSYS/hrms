#!/bin/bash

# HRMS CapRover Troubleshooting Script
echo "=== HRMS CapRover Deployment Troubleshooting ==="
echo ""

# Check if container is running
echo "🔍 Checking container status..."
if pgrep -f "bench start" > /dev/null; then
    echo "✅ Bench process is running"
else
    echo "❌ Bench process is not running"
fi

# Check database connectivity
if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
    echo "🔍 Testing database connection to $DB_HOST:$DB_PORT..."
    if nc -z $DB_HOST $DB_PORT; then
        echo "✅ Database is reachable"
    else
        echo "❌ Cannot connect to database"
    fi
else
    echo "⚠️  Database connection variables not set"
fi

# Check Redis connectivity
if [ -n "$REDIS_CACHE_HOST" ] && [ -n "$REDIS_CACHE_PORT" ]; then
    echo "🔍 Testing Redis connection to $REDIS_CACHE_HOST:$REDIS_CACHE_PORT..."
    if nc -z $REDIS_CACHE_HOST $REDIS_CACHE_PORT; then
        echo "✅ Redis is reachable"
    else
        echo "❌ Cannot connect to Redis"
    fi
else
    echo "⚠️  Redis connection variables not set"
fi

# Check bench directory
echo "🔍 Checking bench directory structure..."
if [ -d "/home/frappe/frappe-bench" ]; then
    echo "✅ Bench directory exists"
    if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
        echo "✅ Frappe app is installed"
    else
        echo "❌ Frappe app is missing"
    fi
    if [ -d "/home/frappe/frappe-bench/apps/erpnext" ]; then
        echo "✅ ERPNext app is installed"
    else
        echo "❌ ERPNext app is missing"
    fi
    if [ -d "/home/frappe/frappe-bench/apps/hrms" ]; then
        echo "✅ HRMS app is installed"
    else
        echo "❌ HRMS app is missing"
    fi
else
    echo "❌ Bench directory does not exist"
fi

# Check site
SITE_NAME=${SITE_NAME:-hrms.localhost}
echo "🔍 Checking site: $SITE_NAME..."
if [ -d "/home/frappe/frappe-bench/sites/$SITE_NAME" ]; then
    echo "✅ Site directory exists"
    if [ -f "/home/frappe/frappe-bench/sites/$SITE_NAME/site_config.json" ]; then
        echo "✅ Site configuration exists"
    else
        echo "❌ Site configuration missing"
    fi
else
    echo "❌ Site directory does not exist"
fi

# Check logs
echo "🔍 Recent bench logs:"
if [ -f "/home/frappe/frappe-bench/logs/bench.log" ]; then
    tail -n 10 /home/frappe/frappe-bench/logs/bench.log
else
    echo "No bench logs found"
fi

echo ""
echo "=== Environment Variables ==="
echo "DB_HOST: ${DB_HOST:-not set}"
echo "REDIS_CACHE_HOST: ${REDIS_CACHE_HOST:-not set}"
echo "SITE_NAME: ${SITE_NAME:-not set}"
echo ""

echo "=== Common Solutions ==="
echo "1. Ensure external database and Redis are running and accessible"
echo "2. Check CapRover environment variables are set correctly"
echo "3. Verify database credentials and permissions"
echo "4. Check if ports are accessible from the container"
echo "5. Review container logs in CapRover dashboard"
