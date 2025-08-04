FROM frappe/bench:latest

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
USER root
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Switch back to frappe user
USER frappe

# Set working directory
WORKDIR /home/frappe

# Copy the HRMS application first
COPY --chown=frappe:frappe . /home/frappe/hrms-app/

# Copy and setup the initialization script
COPY --chown=frappe:frappe docker/init.sh /home/frappe/init.sh
RUN chmod +x /home/frappe/init.sh

# Create volume mount point for persistence
RUN mkdir -p /home/frappe/frappe-bench

# Add a health check script
RUN echo '#!/bin/bash\nif [ -f "/home/frappe/frappe-bench/sites/currentsite.txt" ]; then\n  site=$(cat /home/frappe/frappe-bench/sites/currentsite.txt)\n  curl -f "http://localhost:8000" > /dev/null 2>&1\nelse\n  exit 1\nfi' > /home/frappe/healthcheck.sh && chmod +x /home/frappe/healthcheck.sh

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000 || exit 1

# Start the application
CMD ["/home/frappe/init.sh"]
