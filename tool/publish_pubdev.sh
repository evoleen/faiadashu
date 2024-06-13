#!/usr/bin/env bash

set -e

fvm dart format --fix --set-exit-if-changed lib
fvm flutter pub publish
