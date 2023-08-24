#!/bin/bash
VERSION="0.4"

case $(uname) in
  'Linux')
    download_url="https://github.com/second-state/witc/releases/download/v${VERSION}/witc-v${VERSION}-ubuntu"
    filename="witc-v${VERSION}-ubuntu"
    ;;
  'Darwin')
    download_url="https://github.com/second-state/witc/releases/download/v${VERSION}/witc-v${VERSION}-macos"
    filename="witc-v${VERSION}-macos"
    ;;
  *)
    echo "Unsupported platform: $unamestr"
    exit 1
    ;;
esac

wget ${download_url}
mv ${filename} witc
chmod +x witc
mv witc /usr/local/bin/witc
