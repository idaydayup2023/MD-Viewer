#!/bin/sh
set -eu

MERMAID_SOURCE_DIR="tmp/mermaid-source-11.16.1"
MERMAID_TAG="mermaid@11.16.1"

if [ ! -d "$MERMAID_SOURCE_DIR/.git" ]; then
  git clone --depth 1 --branch "$MERMAID_TAG" \
    https://github.com/mermaid-js/mermaid.git "$MERMAID_SOURCE_DIR"
fi

pnpm --dir "$MERMAID_SOURCE_DIR" install --no-frozen-lockfile --ignore-scripts
pnpm --dir "$MERMAID_SOURCE_DIR" --filter mermaid \
  add dompurify@3.4.13 --save-exact --ignore-scripts
pnpm --dir "$MERMAID_SOURCE_DIR" build:mermaid

cp "$MERMAID_SOURCE_DIR/packages/mermaid/dist/mermaid.min.js" \
  MDViewer/Resources/Renderer/vendor/mermaid.min.js

if ! grep -q 'DOMPurify 3.4.13' MDViewer/Resources/Renderer/vendor/mermaid.min.js; then
  echo 'Mermaid vendor bundle does not contain the audited DOMPurify version.' >&2
  exit 1
fi
