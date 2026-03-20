#!/bin/bash
set -e

# Use a log file in the workspace for visibility
LOG_FILE="/home/vscode/workspace/airflow_setup.log"
echo "[$(date)] Starting Airflow setup script..." | tee -a ${LOG_FILE}

# Ensure Airflow Home exists
export AIRFLOW_HOME=${AIRFLOW_HOME:-/home/vscode/airflow}
mkdir -p ${AIRFLOW_HOME}

# Check if Airflow standalone is already running
if pgrep -f "airflow standalone" > /dev/null; then
    echo "[$(date)] Airflow standalone is already running." | tee -a ${LOG_FILE}
    exit 0
fi

# Initialize Airflow Database
echo "[$(date)] Ensuring database is initialized..." | tee -a ${LOG_FILE}
# We run migrate with a timeout to prevent hanging the whole startup
timeout 60s airflow db migrate || echo "[$(date)] Migration timed out or failed, check logs. Continuing..." | tee -a ${LOG_FILE}

# Start Airflow in standalone mode
echo "[$(date)] Starting Airflow standalone in background..." | tee -a ${LOG_FILE}
nohup airflow standalone >> ${AIRFLOW_HOME}/standalone.log 2>&1 &
PID=$!
echo "[$(date)] Airflow standalone process started with PID: $PID" | tee -a ${LOG_FILE}

# Brief wait to see if it stays up
sleep 5
if pgrep -f "airflow standalone" > /dev/null; then
    echo "[$(date)] Airflow standalone is running. Logs: ${AIRFLOW_HOME}/standalone.log" | tee -a ${LOG_FILE}
else
    echo "[$(date)] WARNING: Airflow standalone failed to start promptly." | tee -a ${LOG_FILE}
fi

echo "[$(date)] Airflow setup script completed." | tee -a ${LOG_FILE}
