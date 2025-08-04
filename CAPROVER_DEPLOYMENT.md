# HRMS CapRover Deployment

This configuration deploys HRMS (Human Resource Management System) on CapRover using external MariaDB and Redis services.

## Features
- ✅ **HRMS-Only Deployment** - No ERPNext, just Frappe + HRMS
- ✅ **External Database Support** - Use your own MariaDB and Redis
- ✅ **GitHub-based Build** - Builds directly from repository
- ✅ **Production Ready** - Optimized for production use

## Deployment Steps

### 1. Environment Variables
Create these environment variables in CapRover:

```bash
# Database Configuration
DB_HOST=your-mariadb-host
DB_ROOT_PASSWORD=your-root-password
ADMIN_PASSWORD=your-admin-password

# Redis Configuration  
REDIS_CACHE_HOST=your-redis-host
REDIS_CACHE_PORT=6379
REDIS_QUEUE_HOST=your-redis-host
REDIS_QUEUE_PORT=6379
REDIS_SOCKETIO_HOST=your-redis-host
REDIS_SOCKETIO_PORT=6379

# Site Configuration
SITE_NAME=your-site-name.com
DEVELOPER_MODE=0
```

### 2. Deploy on CapRover
1. Create a new app in CapRover
2. Go to "Deployment" tab
3. Select "Deploy from Github/Bitbucket/Gitlab"
4. Enter repository: `https://github.com/andylimVSYS/hrms.git`
5. Branch: `feat/caprover` (or your preferred branch)
6. Set environment variables above
7. Deploy!

### 3. Post-Deployment
- Access your HRMS at: `https://your-app.your-caprover-domain.com`
- Login with:
  - Username: `Administrator`
  - Password: (your ADMIN_PASSWORD)

## What Gets Installed
- ✅ Frappe Framework (core)
- ✅ HRMS Application (HR management)
- ❌ ERPNext (explicitly removed for HRMS-only deployment)

## Architecture
```
CapRover App Container
├── frappe/bench:latest (base image)
├── Git clone from GitHub repo
├── Custom init.sh script
├── External MariaDB database
└── External Redis cache/queue
```

## Troubleshooting

### Check Deployment Logs
```bash
# In CapRover app logs, look for:
✅ SUCCESS: HRMS deployment completed!
   You now have Frappe + HRMS (HR Management System)
```

### Verify HRMS-Only Installation
The deployment script actively removes ERPNext:
- Removes ERPNext app directory
- Cleans apps.txt to only include frappe + hrms
- Uninstalls ERPNext from site if present

### Common Issues
1. **Database Connection**: Ensure MariaDB is accessible from CapRover
2. **Redis Connection**: Verify Redis host/port settings
3. **Domain Setup**: Configure your domain in CapRover after deployment

## Files Structure
```
├── captain-definition          # CapRover deployment config
├── docker/init.sh             # Main initialization script
├── .env.example               # Environment variables template
└── hrms/                      # HRMS application source
```

This gives you a clean, HRMS-only deployment without the complexity of ERPNext! 🎯
