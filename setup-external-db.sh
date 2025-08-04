#!/bin/bash

# HRMS External Database Setup Script
# This script helps you configure external MariaDB and Redis for your HRMS deployment

echo "=== HRMS External Database Configuration ==="
echo ""

# Create .env file from template
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "✓ Created .env file from .env.example"
    else
        echo "❌ .env.example file not found!"
        exit 1
    fi
else
    echo "ℹ️  .env file already exists"
fi

echo ""
echo "Please edit the .env file with your external database details:"
echo ""
echo "For MariaDB/MySQL:"
echo "  DB_HOST=your-mariadb-host.com"
echo "  DB_PORT=3306"
echo "  DB_ROOT_PASSWORD=your-secure-password"
echo "  DB_NAME=hrms_production"
echo ""
echo "For Redis:"
echo "  REDIS_CACHE_HOST=your-redis-host.com"
echo "  REDIS_CACHE_PORT=6379"
echo "  REDIS_QUEUE_HOST=your-redis-host.com"
echo "  REDIS_QUEUE_PORT=6379"
echo "  REDIS_SOCKETIO_HOST=your-redis-host.com"
echo "  REDIS_SOCKETIO_PORT=6379"
echo ""
echo "For Site Configuration:"
echo "  SITE_NAME=your-domain.com"
echo "  ADMIN_PASSWORD=your-secure-admin-password"
echo "  DEVELOPER_MODE=0  # Set to 0 for production"
echo ""

# Test database connection (optional)
read -p "Do you want to test database connection? (y/N): " test_db
if [[ $test_db =~ ^[Yy]$ ]]; then
    read -p "Enter MariaDB host: " db_host
    read -p "Enter MariaDB port (default 3306): " db_port
    db_port=${db_port:-3306}
    
    echo "Testing connection to $db_host:$db_port..."
    if command -v nc &> /dev/null; then
        if nc -z $db_host $db_port; then
            echo "✓ Database connection successful!"
        else
            echo "❌ Cannot connect to database at $db_host:$db_port"
        fi
    else
        echo "ℹ️  netcat (nc) not found, cannot test connection"
    fi
fi

echo ""
echo "=== Next Steps ==="
echo "1. Edit the .env file with your actual database details"
echo "2. Make sure your external MariaDB and Redis services are running"
echo "3. Deploy to CapRover with the updated configuration"
echo ""
echo "For CapRover deployment, you can also set these as environment variables"
echo "in the CapRover app settings instead of using the .env file."
