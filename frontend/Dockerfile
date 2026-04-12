# ============================================================
# Frontend — Nginx chỉ serve static files đã build sẵn
# Image size: ~45MB (nginx:alpine)
# ============================================================
FROM nginx:1.27-alpine

# Remove default config
RUN rm /etc/nginx/conf.d/default.conf

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy pre-built Angular output
COPY build/ /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
