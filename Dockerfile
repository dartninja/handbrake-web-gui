FROM ubuntu:cosmic

RUN apt-get -q update
RUN apt-get install --no-install-recommends -y -q apt-transport-https software-properties-common curl gnupg
RUN add-apt-repository -y ppa:stebbins/handbrake-releases
RUN curl https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list
RUN apt-get -q update
RUN apt-get install --no-install-recommends -y -q ffmpeg imagemagick ghostscript dart handbrake-cli

ENV PATH="/usr/lib/dart/bin:${PATH}:${HOME}/.pub-cache/bin"

ADD app/pubspec.yaml /app/pubspec.yaml

RUN cd /app && pub get

ADD app/ /app/

ADD transcode_gui/pubspec.yaml /build/transcode_gui/pubspec.yaml

RUN cd /build/transcode_gui && pub get

ADD . /build

RUN  pub global activate webdev
RUN cd /build/transcode_gui && pub global run webdev build --release --output=/app/web/
RUN rm /build -R

WORKDIR /app

EXPOSE 8080

VOLUME /app/data

CMD []
ENTRYPOINT ["/usr/bin/dart", "/app/server.dart", "--data-dir=/app/data", "--web-dir=/app/web"]