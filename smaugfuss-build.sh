#!/bin/bash
# ============================================================
#  smaugfuss-build.sh
#  Called by AMP's UpdateSources when the user clicks "Update".
#  Must be run from the instance root directory (/AMP/).
#
#  Steps:
#   1. Fetch the latest release tag from the GitHub API
#   2. Download + extract the source tarball in-place
#   3. Compile with make
#   4. Move the binary to the instance root
#   5. Clean up the source tree (keep data dirs)
# ============================================================
set -eux

REPO="Arthmoor/SmaugFUSS"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo "--- SmaugFUSS build script starting ---"
echo "Working directory: $(pwd)"

# Step 1: Resolve latest release tag
echo "Fetching latest release tag..."
LATEST=$(curl -fsSL "${API_URL}" \
    | grep '"tag_name"' \
    | head -1 \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

if [ -z "${LATEST}" ]; then
    echo "ERROR: Could not determine latest release tag." >&2
    exit 1
fi
echo "Latest release: ${LATEST}"

# Step 2: Download and extract source
TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/${LATEST}.tar.gz"
echo "Downloading ${TARBALL_URL}..."
# Extract into a temp directory first so we don't clobber existing data dirs
mkdir -p /tmp/smaugfuss-src
curl -fsSL "${TARBALL_URL}" \
    | tar -xz --strip-components=1 -C /tmp/smaugfuss-src

# Step 3: Compile
echo "Compiling..."
cd /tmp/smaugfuss-src/src
make

# Step 4: Move binary to instance root
echo "Installing binary..."
mv /tmp/smaugfuss-src/smaug "$(dirname "$0")/../smaug" 2>/dev/null || \
    mv smaug /AMP/smaug

# Step 5: Copy data directories to instance root (only if not already present,
#         so existing player/area data is not overwritten on updates)
INSTANCE_ROOT="/AMP"
for dir in area backup boards building clans classes color corpses \
            councils deity deleted doc gods hotboot houses log mudprogs \
            new player races system vault watch; do
    if [ ! -d "${INSTANCE_ROOT}/${dir}" ]; then
        echo "Copying fresh ${dir}/ to instance root..."
        cp -r "/tmp/smaugfuss-src/${dir}" "${INSTANCE_ROOT}/${dir}" 2>/dev/null || true
    else
        echo "Skipping ${dir}/ (already exists, preserving existing data)"
    fi
done

# Step 6: Clean up source tree
echo "Cleaning up..."
rm -rf /tmp/smaugfuss-src

echo "--- SmaugFUSS build complete ---"
