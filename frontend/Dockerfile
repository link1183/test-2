FROM debian:12.9 AS build

# Install Flutter dependencies
RUN apt-get update && apt-get install -y \
  curl \
  git \
  unzip \
  xz-utils \
  zip \
  libglu1-mesa

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:$PATH"
RUN flutter channel stable
RUN flutter upgrade
RUN flutter config --enable-web

# Copy app files
WORKDIR /app
COPY . .

RUN flutter pub get

# Build web app
RUN flutter build web

# Production stage
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
