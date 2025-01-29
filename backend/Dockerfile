FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o server

FROM debian:12.9-slim
RUN apt-get update && apt-get install -y \
  sqlite3 \
  libsqlite3-dev \
  curl \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN mkdir -p /data && chown -R 1000:1000 /data /app

COPY --from=build /app/server ./
RUN chown -R 1000:1000 /app/server && chmod 755 /app/server

USER 1000:1000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["./server"]
