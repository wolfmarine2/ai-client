#!/bin/sh
set -eu

# Allow users to have scripts run on container startup to prepare workspace.
# https://github.com/dhzq/code-server/issues/5177
if [ -d "${ENTRYPOINTD}" ]; then
  find "${ENTRYPOINTD}" -type f -executable -print -exec {} \;
fi

exec "$@"