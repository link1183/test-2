FROM debian:12.9-slim AS build

# Install Flutter dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  curl \
  git \
  unzip \
  xz-utils \
  zip \
  libglu1-mesa \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd -r flutter && useradd -r -g flutter -m -d /home/flutter flutter
USER flutter
WORKDIR /home/flutter

# Install Flutter
RUN curl -sSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.0-stable.tar.xz -o flutter.tar.xz \
  && tar xf flutter.tar.xz \
  && rm flutter.tar.xz

ENV PATH="/home/flutter/flutter/bin:${PATH}"

RUN flutter config --enable-web

USER root
RUN mkdir -p /app && chown -R flutter:flutter /app
USER flutter

# Copy app files
WORKDIR /app
COPY --chown=flutter:flutter pubspec.* ./

COPY --chown=flutter:flutter . .

RUN flutter pub get && flutter build web --profile --dart-define=Dart2jsOptimization=O0

# Production stage
FROM nginx:alpine-slim

RUN echo 'events { worker_connections 1024; }' > /etc/nginx/nginx.conf \
  && echo 'http {' >> /etc/nginx/nginx.conf \
  && echo '    include /etc/nginx/mime.types;' >> /etc/nginx/nginx.conf \
  && echo '    include /etc/nginx/conf.d/*.conf;' >> /etc/nginx/nginx.conf \
  && echo '}' >> /etc/nginx/nginx.conf

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY ./ssl/cert.pem ./ssl/key.pem /etc/nginx/ssl/
