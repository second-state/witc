$VERSION = "0.4"

wget "https://github.com/second-state/witc/releases/download/v${VERSION}/witc-v${VERSION}-windows.exe"

mv "witc-v${VERSION}-windows.exe" witc.exe
chmod +x witc.exe
