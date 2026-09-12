# Stage 1: Build Flutter Web application
FROM ghcr.io/cirruslabs/flutter:stable AS builder

# Install pinned Flutter SDK 3.47.4 (Dart SDK 3.13.3, satisfying ^3.12.2)
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.4-stable.tar.xz | tar -xJ -C /sdks \
    && git config --global --add safe.directory /sdks/flutter \
    && flutter config --no-analytics \
    && flutter precache --web

WORKDIR /app

# Accept build-time API base URL (defaults to browser-accessible backend endpoint)
ARG API_BASE_URL=http://localhost:8000

# Copy pubspec files first to leverage Docker layer caching
COPY pubspec.yaml pubspec.lock* ./

RUN flutter pub get

# Copy source code and assets
COPY . .

# Build Flutter Web in release mode
RUN flutter build web --release --no-tree-shake-icons --dart-define=API_BASE_URL=${API_BASE_URL}

# Stage 2: Serve using lightweight Nginx
FROM nginx:alpine

# Copy built web artifacts
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=5s \
    CMD wget -q --spider http://127.0.0.1/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
