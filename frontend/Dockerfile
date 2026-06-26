# Stage 1: Build assets
FROM node:20-alpine AS builder
 
#Ensure curl is installed (required for the health check)
RUN apk add --no-cache curl

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build


# Stage 2: Serve with Nginx
FROM nginx:1.25-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
# Custom Nginx config to support frontend single-page routing (SPA)
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80

# Add the HEALTHCHECK instruction
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
