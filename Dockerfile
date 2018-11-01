FROM ubuntu:cosmic

RUN apt-get -q update
RUN apt-get install --no-install-recommends -y -q apt-transport-https software-properties-common
RUN add-apt-repository ppa:stebbins/handbrake-releases
RUN sh -c 'curl https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
RUN sh -c 'curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
RUN apt-get -q update
RUN apt-get install --no-install-recommends -y -q ffmpeg imagemagick ghostscript dart handbrake-cli

ADD app/pubspec.yaml /app/pubspec.yaml

RUN cd /app && pub get

ADD transcode_gui/pubspec.yaml /build/transcode_gui/pubspec.yaml

RUN cd /build/transcode_gui && pub get

ADD . /build

RUN cd /build/transcode_gui && pub build --mode=release --output=/app/web/ && cd / && rm /build -R

WORKDIR /app

EXPOSE 8080

VOLUME /app/data

CMD []
ENTRYPOINT ["/usr/bin/dart", "server.dart", "--data-dir=/app/data", "--web-dir=/app/web"]