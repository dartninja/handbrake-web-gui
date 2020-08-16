FROM archlinux:20200705

ENV PATH="/usr/lib/dart/bin:${PATH}:/root/.pub-cache/bin"

RUN pacman -Sy --noconfirm ffmpeg handbrake-cli dart

RUN pub global activate webdev

WORKDIR /build/gui

COPY gui/pubspec.yaml /build/gui/pubspec.yaml

RUN pub get

WORKDIR /build/server

COPY server/pubspec.yaml /build/server/pubspec.yaml

RUN pub get

WORKDIR /build/gui

COPY gui/ /build/gui

RUN webdev build --release --output=web:/app/web/ && cd / && rm /build/gui -R

WORKDIR /build/server

COPY server/ /build/server

RUN dart2native bin/server.dart -o /app/server && cd / && rm /build -R

EXPOSE 8080

VOLUME /app/data

ENTRYPOINT ["/app/server", "--data-dir=/app/data", "--web-dir=/app/web"]