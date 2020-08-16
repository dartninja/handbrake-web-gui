#!/bin/sh

cd server
pub get
dart2native bin/server.dart -o bin/server
cd ../gui
pub global activate webdev
pub get
pub global run webdev build --release --output=web:build