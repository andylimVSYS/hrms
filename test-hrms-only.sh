#!/bin/bash

# Test script to verify HRMS-only deployment
echo "🧪 Testing HRMS-Only Deployment"
echo "================================"

# Check if required environment variables are set
if [ -z "$SITE_NAME" ]; then
    echo "❌ SITE_NAME not set, using default: hrms.test"
    export SITE_NAME="hrms.test"
fi

echo "📋 Configuration Check:"
echo "  Site Name: $SITE_NAME"
echo "  Expected Apps: frappe + hrms (NO erpnext)"
echo ""

# Run the initialization script
echo "🚀 Running init.sh..."
cd /home/frappe/frappe-bench && bash /tmp/init.sh

echo ""
echo "🔍 Post-deployment Verification:"
echo "================================"

# Check apps.txt
echo "📋 Apps.txt content:"
cat apps/apps.txt 2>/dev/null || echo "❌ apps.txt not found"

echo ""
echo "📁 App directories:"
ls -1 apps/ | grep -v apps.txt | sed 's/^/  /'

echo ""
echo "📦 Apps installed on site:"
bench --site ${SITE_NAME} list-apps 2>/dev/null || echo "❌ Could not list site apps"

echo ""
echo "✅ Verification Summary:"
if [ -d "apps/erpnext" ]; then
    echo "  ❌ ERPNext directory found (should be removed)"
else
    echo "  ✅ ERPNext directory not found (correct)"
fi

if grep -q "erpnext" apps/apps.txt 2>/dev/null; then
    echo "  ❌ ERPNext found in apps.txt (should be removed)"
else
    echo "  ✅ ERPNext not in apps.txt (correct)"
fi

if bench --site ${SITE_NAME} list-apps 2>/dev/null | grep -q "erpnext"; then
    echo "  ❌ ERPNext installed on site (should be removed)"
else
    echo "  ✅ ERPNext not installed on site (correct)"
fi

if bench --site ${SITE_NAME} list-apps 2>/dev/null | grep -q "hrms"; then
    echo "  ✅ HRMS installed on site (correct)"
else
    echo "  ❌ HRMS not installed on site (needs fixing)"
fi

echo ""
echo "🎯 Result: HRMS-Only deployment $(if bench --site ${SITE_NAME} list-apps 2>/dev/null | grep -q "hrms" && ! bench --site ${SITE_NAME} list-apps 2>/dev/null | grep -q "erpnext"; then echo "✅ SUCCESS"; else echo "❌ FAILED"; fi)"
