#!/bin/bash
# MarioCraft installer. Run by install.bat (or from any MSYS2 shell: bash install.sh).
#
# Builds everything on this PC from source, with your own copies of the games:
#   1. Java 25 and Prism Launcher are there    4. SM64: sm64coopdx v1.5.1 + MarioCraft
#   2. the build tools (MSYS2 packages)        5. the MarioCraft Minecraft mod (SkyCraft 0.1.2 + MarioCraft)
#   3. your Super Mario 64 ROM                 6. "MarioCraft Launcher.exe" and the Prism Launcher instance
# Safe to run again: it picks up where it left off, and updates an older MarioCraft install.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
export PATH="/mingw64/bin:/usr/bin:$PATH"

SM64_REPO=${MARIOCRAFT_SM64_REPO:-https://github.com/coop-deluxe/sm64coopdx.git}
SM64_COMMIT=8cd6e5977d9f920d51ca71f2c61801d019ed79c6   # v1.5.1
SKY_REPO=${MARIOCRAFT_SKY_REPO:-https://github.com/chasmlol/SkyCraft.git}
SKY_COMMIT=bfcaf178524b92c2cdeb88e4ce0f13ef9ded6f32    # v0.1.2
ROM_SHA1=9bef1128717f958171a4afac3ed78ee2bb4e86ce      # Super Mario 64 (USA), .z64

fail() {
    echo
    echo "PROBLEM: $*"
    exit 1
}

# Opens a web page in the player's browser.
open_page() {
    [ -n "${MARIOCRAFT_NO_BROWSER:-}" ] && return  # (for testing the installer)
    # (Windows' own URL handler: no cmd in between to cut the link at its "&"s)
    rundll32.exe url.dll,FileProtocolHandler "$1" >/dev/null 2>&1 &
}

# ---- Where MarioCraft is: SM64's build can't cope with spaces in the folder's path (a "John Smith"
# ---- user folder, "New folder"...) or with a long one (Windows' path length limit).
winhere="$(cygpath -w "$here")"
case "$here" in
    *" "*) fail "MarioCraft's folder has a space in its path ($winhere), and SM64 can't be built there. Move the MarioCraft folder to  C:\\MarioCraft  and run install.bat from there." ;;
esac
if [ ${#winhere} -gt 80 ]; then
    fail "MarioCraft's folder path is too long ($winhere) for SM64's build. Move the MarioCraft folder to  C:\\MarioCraft  and run install.bat from there."
fi

# ---- What has to be installed first: checked before anything long, so nobody waits 20 minutes
# ---- to find out. Whatever is missing has its download page opened, with what to pick on it.
echo "== 1/6  Java 25 and Prism Launcher"
JAVA_PAGE="https://adoptium.net/temurin/releases/?os=windows&arch=x64&package=jdk&version=25"
PRISM_PAGE="https://prismlauncher.org/download/windows/"

java_home=""
local_app="$(cygpath -u "${LOCALAPPDATA:-C:\\}")"
on_path=""
if command -v java >/dev/null 2>&1; then
    on_path="$(dirname "$(dirname "$(command -v java)")")"
fi
for candidate in "${JAVA_HOME:-}" "$on_path" "$local_app/Programs/Eclipse Adoptium"/jdk-25* "/c/Program Files/Eclipse Adoptium"/jdk-25* \
                 "/c/Program Files/Java"/jdk-25* "/c/Program Files/Microsoft"/jdk-25* "/c/Program Files/Zulu"/zulu-25*; do
    [ -n "$candidate" ] || continue
    unixpath="$(cygpath -u "$candidate" 2>/dev/null || echo "$candidate")"
    if [ -x "$unixpath/bin/java.exe" ] && [ -x "$unixpath/bin/javac.exe" ] && "$unixpath/bin/java.exe" -version 2>&1 | grep -q 'version "25'; then
        java_home="$unixpath"
        break
    fi
done

prism=""
for candidate in "$local_app/Programs/PrismLauncher/prismlauncher.exe" "/c/Program Files/PrismLauncher/prismlauncher.exe" \
                 "/c/Program Files (x86)/PrismLauncher/prismlauncher.exe" "$local_app/SkyCraft/Prism/prismlauncher.exe"; do
    if [ -f "$candidate" ]; then
        prism="$candidate"
        break
    fi
done

if [ -z "$java_home" ] || [ -z "$prism" ]; then
    echo
    echo "Before MarioCraft can be installed, this PC needs:"
    if [ -z "$java_home" ]; then
        echo
        echo "  * JAVA 25 (JDK).  Opening its download page in your browser..."
        echo "      On that page pick:  Version 25 - Windows - x64 - JDK  and download the  .msi  installer."
        echo "      (It must be version 25, and the JDK, not the JRE. Older or newer Java won't work.)"
        echo "      While installing, on \"Custom Setup\", click \"Set JAVA_HOME variable\" and choose"
        echo "      \"Will be installed on local hard drive\"."
        open_page "$JAVA_PAGE"
    fi
    if [ -z "$prism" ]; then
        echo
        echo "  * PRISM LAUNCHER (it runs Minecraft for MarioCraft).  Opening its download page in your browser..."
        echo "      Download the Windows installer (\"Setup\", not \"Portable\") and install it."
        echo "      Then open Prism Launcher once: Accounts (top right) - Manage Accounts - Add Microsoft,"
        echo "      and sign in with the Microsoft account that owns Minecraft: Java Edition."
        open_page "$PRISM_PAGE"
    fi
    echo
    fail "install what's listed above, then run install.bat again."
fi
export JAVA_HOME="$(cygpath -w "$java_home")"
echo "OK: Java 25 ($JAVA_HOME)"
echo "OK: Prism Launcher ($(cygpath -w "$prism"))"

echo "== 2/6  Build tools"
missing=0
for tool in git make python3 unzip gcc sdl2-config; do
    command -v "$tool" >/dev/null || missing=1
done
if [ $missing = 1 ]; then
    echo "Installing them with MSYS2's pacman (a few minutes the first time)..."
    pacman -S --needed --noconfirm git make python unzip mingw-w64-x86_64-gcc mingw-w64-x86_64-SDL2 mingw-w64-x86_64-glew \
        || fail "pacman couldn't install the build tools. Open \"MSYS2 MINGW64\" from the Start menu, run  pacman -Syu  (twice if it asks), then run install.bat again."
fi
echo "OK"

echo "== 3/6  Your Super Mario 64 ROM"
rom="$here/baserom.us.z64"
# Any name will do: every .z64, .n64 and .v64 file in this folder is looked at, byte-swapped dumps
# (.v64, .n64) put the right way round, and the one that is Super Mario 64 (USA) becomes
# baserom.us.z64. The player's own file is left as it is.
python3 - "$here" "$ROM_SHA1" <<'PYEOF' || fail "No Super Mario 64 (USA) ROM found (see above). Put your own ROM file (.z64, .n64 or .v64; any name) in this folder, next to install.bat, then run install.bat again. MarioCraft doesn't include it."
import hashlib, os, sys
here, want = sys.argv[1], sys.argv[2]
other = {
    "8a20a5c83d6ceb0f0506cfc9fa20d8f438cafe51": "the Japanese version",
    "4ac5721683d0e0b6bbb561b58a71740845dceea9": "the European version",
    "3f319ae697533a255a1003d09202379d78d5a2e0": "the Shindou (Japanese rumble) version",
}
names = sorted(f for f in os.listdir(here) if f.lower().endswith((".z64", ".n64", ".v64")))
names.sort(key=lambda f: f != "baserom.us.z64")  # (one already set up first)
if not names:
    print("  There's no .z64, .n64 or .v64 file in this folder.")
for name in names:
    data = open(os.path.join(here, name), "rb").read()
    head = data[:4]
    if head == b"\x80\x37\x12\x40":
        z64 = data
    elif head == b"\x37\x80\x40\x12":  # .v64: every two bytes swapped
        z = bytearray(len(data))
        z[0::2], z[1::2] = data[1::2], data[0::2]
        z64 = bytes(z)
    elif head == b"\x40\x12\x37\x80":  # .n64: every four bytes reversed
        z = bytearray(len(data))
        z[0::4], z[1::4], z[2::4], z[3::4] = data[3::4], data[2::4], data[1::4], data[0::4]
        z64 = bytes(z)
    else:
        print("  %s: not a Nintendo 64 ROM" % name)
        continue
    sha = hashlib.sha1(z64).hexdigest()
    if sha == want:
        if name != "baserom.us.z64":
            with open(os.path.join(here, "baserom.us.z64"), "wb") as f:
                f.write(z64)
        print("  Using %s" % name)
        sys.exit(0)
    print("  %s: %s, not Super Mario 64 (USA)" % (name, other.get(sha, "a different game or a modified ROM")))
sys.exit(1)
PYEOF
[ "$(sha1sum "$rom" | cut -d' ' -f1)" = "$ROM_SHA1" ] || fail "baserom.us.z64 couldn't be set up"
# (sm64coopdx also looks for it here when it starts)
if [ -n "${APPDATA:-}" ]; then
    appdata="$(cygpath -u "$APPDATA")"
    if [ ! -f "$appdata/sm64coopdx/baserom.us.z64" ]; then
        mkdir -p "$appdata/sm64coopdx" && cp "$rom" "$appdata/sm64coopdx/baserom.us.z64"
    fi
fi
echo "OK"

# Gets an upstream project at the pinned version with MarioCraft's patch on it.
get_source() {
    local dir="$1" repo="$2" commit="$3" patch="$here/patches/$4"
    if [ ! -d "$here/$dir/.git" ]; then
        rm -rf "$here/$dir"
        echo "Downloading $dir..."
        git clone -q "$repo" "$here/$dir" || fail "couldn't download $dir from $repo (are you online?)"
    fi
    cd "$here/$dir" || exit 1
    if git apply --reverse --check "$patch" 2>/dev/null; then
        echo "OK: $dir already has this MarioCraft"
        return
    fi
    # A fresh copy, or an older MarioCraft: back to the upstream version, then this patch.
    git fetch -q origin 2>/dev/null
    git reset -q --hard "$commit" || fail "couldn't get $dir at version $commit"
    git clean -q -fd -e build -e baserom.us.z64
    git apply --whitespace=nowarn "$patch" || fail "MarioCraft's patch didn't apply to $dir"
    echo "OK: $dir patched"
}

echo "== 4/6  Super Mario 64 (sm64coopdx + MarioCraft)"
get_source sm64coopdx "$SM64_REPO" "$SM64_COMMIT" sm64coopdx.patch
cp -f "$rom" "$here/sm64coopdx/baserom.us.z64"
: > "$here/sm64coopdx-build.log"
if tasklist 2>/dev/null | grep -qi "sm64coopdx.exe"; then
    fail "SM64 is running: close it, then run install.bat again."
fi
# As many compile jobs as the PC has room for: one per core ran some PCs out of memory (some of
# sm64coopdx's files need a lot each). About 2 GB a job, at most 8.
cores="$(nproc 2>/dev/null || echo 2)"
mem_gb=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 4194304) / 1048576 ))
jobs=$(( mem_gb / 2 ))
[ "$jobs" -gt "$cores" ] && jobs=$cores
[ "$jobs" -gt 8 ] && jobs=8
[ "$jobs" -lt 1 ] && jobs=1
echo "Building with $jobs jobs (10-20 minutes the first time; the log is in sm64coopdx-build.log)..."
built=0
for try_jobs in "$jobs" 2 1; do
    if (cd "$here/sm64coopdx" && make -j"$try_jobs" >> "$here/sm64coopdx-build.log" 2>&1); then
        built=1
        break
    fi
    [ "$try_jobs" = 1 ] && break
    # (already compiled files are kept: a retry only does what's left)
    echo "  The build stopped (the PC may have run short of memory): trying again with fewer jobs..."
done
if [ $built != 1 ]; then
    tail -n 25 "$here/sm64coopdx-build.log"
    fail "SM64 didn't build (the end of the log is above; all of it is in sm64coopdx-build.log). Close other programs and run install.bat again."
fi
echo "OK"

echo "== 5/6  The MarioCraft Minecraft mod (SkyCraft + MarioCraft)"
get_source SkyCraft "$SKY_REPO" "$SKY_COMMIT" skycraft.patch
echo "Building (Gradle downloads Minecraft 26.3's build files the first time; the log is in minecraft-mod-build.log)..."
(cd "$here/SkyCraft/fabric" && cmd //c "$(cygpath -w "$here/SkyCraft/fabric/gradlew.bat")" build > "$here/minecraft-mod-build.log" 2>&1) || {
    tail -n 25 "$here/minecraft-mod-build.log"
    fail "the Minecraft mod didn't build (all of it is in minecraft-mod-build.log)"
}
echo "OK"

echo "== 6/6  Launcher and Prism Launcher"
bash "$here/launcher/build.sh" || fail "the launcher didn't build"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$here/launcher/setup-prism.ps1")" \
    || fail "Prism Launcher isn't set up: install it from https://prismlauncher.org, sign in to your Microsoft account in it once, then run install.bat again."

echo
echo "Done! Double-click \"MarioCraft Launcher.exe\" in this folder to play."
