FROM mcr.microsoft.com/devcontainers/python:3.13-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    libffi-dev \
    libpq-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set Airflow Home
ENV AIRFLOW_HOME=/home/vscode/airflow

# Install Airflow and other dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir "apache-airflow[google,postgres]==3.1.8" -r /tmp/requirements.txt

# Create airflow directory and set permissions
RUN mkdir -p ${AIRFLOW_HOME} && \
    chown -R vscode:vscode ${AIRFLOW_HOME} && \
    chmod -R 755 ${AIRFLOW_HOME}

# Copy setup script and ensure it is executable
COPY .devcontainer/setup-airflow.sh /usr/local/bin/setup-airflow.sh
RUN chmod +x /usr/local/bin/setup-airflow.sh

# Ensure /tmp has correct permissions for VS Code server installation
RUN chmod 1777 /tmp

# Expose Airflow API/Webserver port
EXPOSE 8080
