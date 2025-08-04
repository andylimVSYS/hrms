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
    && rm -rf /var/lib/apt/lists/*

# Switch back to frappe user
USER frappe

# Set working directory
WORKDIR /home/frappe

# Copy the HRMS application first
COPY --chown=frappe:frappe . /home/frappe/hrms-app/

# Copy environment configuration
COPY --chown=frappe:frappe .env* /home/frappe/

# Copy and setup the initialization script
COPY --chown=frappe:frappe docker/init.sh /home/frappe/init.sh
RUN chmod +x /home/frappe/init.sh

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000 || exit 1

# Start the application
CMD ["/home/frappe/init.sh"]
