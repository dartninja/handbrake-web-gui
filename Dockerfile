FROM archlinux:latest

RUN pacman -Sy --noconfirm ffmpeg handbrake-cli

COPY server/bin/server /app/server

COPY gui/build/ /app/web/

EXPOSE 8080

VOLUME /app/data

CMD [""]
ENTRYPOINT ["/app/server", "--data-dir=/app/data", "--web-dir=/app/web"]