#!/bin/bash
set -eu -o pipefail

PYTHON=3.12

VERSION=$(grep -E '^version\s*=' pyproject.toml | sed 's/^version = "\(.*\)"$/\1/')
PYAPP_VERSION=$(sed -n 's/.*ofek\/pyapp@v//p' .github/workflows/dependabot_hack.yml)

PYAPP_DIST_DIR=".pyapp/dist/${VERSION}"
PYAPP_BUILD_DIR=".pyapp/build"
WAM_FILENAME="watchmaker-${VERSION}-standalone-linux-x86_64"

# Python standalone build info
PYTHON_BUILD_STANDALONE_VERSION="20251031"
PYTHON_FULL_VERSION="3.12.12"
PYTHON_RELEASE="cpython-${PYTHON_FULL_VERSION}+${PYTHON_BUILD_STANDALONE_VERSION}-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_BUILD_STANDALONE_VERSION}/${PYTHON_RELEASE}"

echo "Building PyApp standalone for watchmaker v${VERSION}..."
echo "Using PyApp v${PYAPP_VERSION}"
echo "Using Python ${PYTHON_FULL_VERSION} from python-build-standalone"

echo "-----------------------------------------------------------------------"
cargo --version
rustc --version
echo "-----------------------------------------------------------------------"

# Find the wheel file
WHEEL_FILE=$(find dist -name "watchmaker-${VERSION}-py3-none-any.whl" | head -n 1)
if [ -z "$WHEEL_FILE" ]; then
    echo "Error: Could not find wheel file for version ${VERSION}"
    exit 1
fi
WHEEL_FILE_ABS=$(realpath "$WHEEL_FILE")
echo "Using wheel: $WHEEL_FILE_ABS"

# Download and prepare custom Python distribution
echo "Downloading Python standalone distribution..."
mkdir -p "$PYAPP_BUILD_DIR"
cd "$PYAPP_BUILD_DIR"

if [ ! -f "$PYTHON_RELEASE" ]; then
    curl -L -o "$PYTHON_RELEASE" "$PYTHON_URL"
fi

echo "Extracting Python distribution..."
tar -xzf "$PYTHON_RELEASE"

PYTHON_DIR="python"
PYTHON_BIN="${PYTHON_DIR}/bin/python${PYTHON}"

echo "Installing watchmaker and dependencies into custom Python distribution..."
"$PYTHON_BIN" -m pip install --upgrade pip
"$PYTHON_BIN" -m pip install "$WHEEL_FILE_ABS" boto3

echo "Creating custom distribution archive..."
CUSTOM_DIST="cpython-${PYTHON_FULL_VERSION}-watchmaker-${VERSION}.tar.gz"
tar -czf "$CUSTOM_DIST" "$PYTHON_DIR"

echo "Custom distribution created: $CUSTOM_DIST"
ls -lh "$CUSTOM_DIST"

# Build the standalone with PyApp via cargo install
echo "Building PyApp standalone with cargo install..."
cd ../..
mkdir -p "$PYAPP_DIST_DIR"

export PYAPP_PROJECT_NAME="watchmaker"
export PYAPP_PROJECT_VERSION="$VERSION"
export PYAPP_DISTRIBUTION_EMBED=1
export PYAPP_DISTRIBUTION_PATH="$(realpath "${PYAPP_BUILD_DIR}/${CUSTOM_DIST}")"
export PYAPP_DISTRIBUTION_PYTHON_PATH="python/bin/python${PYTHON}"
export PYAPP_FULL_ISOLATION=1
export PYAPP_SKIP_INSTALL=1

cargo install pyapp --locked --no-track --version "${PYAPP_VERSION}" --root .

# Remove cargo tracking files
rm -f .crates.toml .crates2.json

# Rename the binary
mv bin/pyapp "${PYAPP_DIST_DIR}/${WAM_FILENAME}"

echo "Creating sha256 hashes of standalone binary..."
(cd "$PYAPP_DIST_DIR"; sha256sum "$WAM_FILENAME" > "${WAM_FILENAME}.sha256")
cat "${PYAPP_DIST_DIR}/${WAM_FILENAME}.sha256"

echo "Setting executable permissions..."
chmod +x "${PYAPP_DIST_DIR}/${WAM_FILENAME}"

echo "Checking standalone binary version..."
eval "${PYAPP_DIST_DIR}/${WAM_FILENAME}" --version

echo "Listing files in dist dir..."
ls -alRh "$PYAPP_DIST_DIR"
