#!/usr/bin/env bash
# Upgrades and fetches packages for faiadashu and all related projects
fvm flutter pub upgrade
fvm flutter pub get

pushd faiadashu_online || exit
fvm flutter pub upgrade
fvm flutter pub get
popd || exit

pushd faiabench || exit
fvm flutter pub upgrade
fvm flutter pub get
popd || exit

pushd example || exit
fvm flutter pub upgrade
fvm flutter pub get
popd || exit
