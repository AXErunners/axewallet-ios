#!/usr/bin/env bash

pushd "../AxeSync/"
AXESYNC_COMMIT=`git rev-parse HEAD`
popd
echo "$AXESYNC_COMMIT" > AxeSyncCurrentCommit
