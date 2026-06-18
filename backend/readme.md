# Node.js Docker Application for Zuriapp Backend

Ensure the app runs on local machine and dockerised image running locally.

## Features

- .env not committed to git
- .env.example as template showing which variables are required with placeholder values. This is committed to Git so teammates know what to set up.
- .gitignore explicitely list .env to prevent accidental commits
- Docker images created and run successfully on localhost

## Project Structure
```
zuriapp-backend/
├── server.js          # nodejs application
├── package.json       # Node dependencies
├── Dockerfile         # Docker build instructions
├── .dockerignore      # Files to exclude from Docker build
├── data
    ├── product.js    # data to load on website
└── README.md          # This file
```

## Prerequisites

- Docker installed on your system
- Node is installed on your system
- Basic knowledge of command line

## Quick Start- Run App Locally

### Local Development (without Docker)

For local development , Node must be installed on your system 

```bash

# Install dependencies
npm install

# Run application
npm run dev

# Access at http://localhost:5000
```

## RUN APP AS CONTAINER
###  Build the Docker Image
```bash
# Navigate to project directory
cd zuriapp-backend

# Build the image with tag 'zuriapp-backend:v1.0'
docker build -t zuriapp-backend:v1.0 .

# Verify image was created
docker images | grep zuriapp-backend:v1.0
```

### 2. Run the Container
```bash
# Run container in detached mode, mapping port 5000
docker run -d -p 5000:5000 --name zuriapp-backend-container zuriapp-backend:v1.0

# Verify container is running
docker ps

### 3. Access the Application

Open your browser and visit:
- **Main Page**: http://localhost:5000

### 4. View Container Logs
```bash
# View logs
docker logs zuriapp-backend-container

# Follow logs in real-time
docker logs -f zuriapp-backend-container
```

### 5. Stop and Remove Container
```bash
# Stop the container
docker stop zuriapp-backend-container

# Remove the container
docker rm zuriapp-backend-container
```
