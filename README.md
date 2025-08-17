# Gotify Load Testing Suite

A comprehensive testing and load testing toolkit for [Gotify](https://gotify.net/) server instances.

## 📋 Overview

This project provides two main components:
- **Gotify Tester** (`main.js`) - Node.js application for functional testing of Gotify API
- **Load Testing Suite** (`load.sh`) - Automated performance testing using Vegeta

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Node.js & npm
- Bash shell

### Setup & Run

1. **Start Gotify Server**
   ```bash
   docker-compose up -d
   ```
   Server will be available at `http://localhost:8080`
   - Username: `admin`
   - Password: `admin`

2. **Install Dependencies**
   ```bash
   npm install axios ws
   ```

3. **Run Functional Tests**
   ```bash
   node main.js
   ```

4. **Run Load Tests**
   ```bash
   chmod +x load.sh
   ./load.sh
   ```

## 🔧 Components

### Docker Compose Configuration
- **Service**: `gotify/server` image
- **Port**: 8080:80 mapping
- **Volume**: `./gotify_data` for persistent data
- **Default credentials**: admin/admin

### Functional Tester (`main.js`)
Node.js application that performs comprehensive API testing:

**Features:**
- Client token authentication
- Application creation & management
- Message sending with different priorities
- Real-time WebSocket message listening
- Message retrieval and cleanup

**Test Flow:**
1. Obtains client authentication token
2. Creates test application
3. Establishes WebSocket connection
4. Sends test messages (low, normal, high priority)
5. Retrieves all messages
6. Cleans up test data

### Load Testing Suite (`load.sh`)

**Test Scenarios:**
- **Light Load**: 10 req/s for 30s (small messages)
- **Medium Load**: 50 req/s for 60s (medium messages)  
- **Heavy Load**: 100 req/s for 30s (small messages)
- **Burst Test**: 200 req/s for 10s (small messages)
- **Large Message Test**: 20 req/s for 30s (large messages)
- **Stress Test**: Maximum rate for 15s (small messages)

**Generated Reports:**
- Text reports with latency statistics
- JSON reports for programmatic analysis
- HTML plots for visual analysis
- Histogram data for response time distribution
- Combined summary report
- HTML index for easy navigation

## 📊 Output Files

Load test results are saved in `vegeta_results/` directory:
- `*_report.txt` - Detailed text reports
- `*_report.json` - JSON formatted results
- `*_plot.html` - Visual performance plots
- `*_histogram.txt` - Response time histograms
- `combined_report_*.txt` - Summary of all tests
- `index_*.html` - Navigation page for all results

## 📝 Customization

### Modify Test Parameters
Edit configuration variables in the scripts:
- `GOTIFY_URL` - Server endpoint
- `USERNAME`/`PASSWORD` - Authentication credentials
- Load test rates and durations in `load.sh`
