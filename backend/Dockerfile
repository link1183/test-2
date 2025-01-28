FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
COPY . .
RUN dart pub get 
RUN dart compile exe bin/server.dart -o server

FROM debian:12.9
RUN apt-get update && apt-get install -y sqlite3 libsqlite3-dev
COPY --from=build /app/server /app/server
WORKDIR /app
CMD ["./server"]
