FROM ubuntu:cosmic

RUN apt-get -q update \
    && apt-get install --no-install-recommends -y -q apt-transport-https software-properties-common curl gnupg \
    && add-apt-repository -y ppa:stebbins/handbrake-releases \
    && curl https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list \
    && apt-get -q update \
    && apt-get install --no-install-recommends -y -q ffmpeg imagemagick ghostscript dart handbrake-cli \
    && apt-get clean

ENV PATH="/usr/lib/dart/bin:${PATH}:/root/.pub-cache/bin"

RUN pub global activate webdev

WORKDIR /app

COPY app/pubspec.yaml /app/pubspec.yaml

RUN pub get

WORKDIR /build

COPY transcode_gui/pubspec.yaml /build/pubspec.yaml

RUN pub get

COPY transcode_gui/ /build/

RUN webdev build --release --output=web:/app/web/ && cd / && rm /build -R

WORKDIR /app

COPY app/ /app/

EXPOSE 8080

VOLUME /app/data

CMD [""]
ENTRYPOINT ["/usr/bin/dart", "/app/bin/server.dart", "--data-dir=/app/data", "--web-dir=/app/web"]