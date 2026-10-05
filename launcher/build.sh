#!/bin/bash
# Builds "MarioCraft Launcher.exe" into the mariocraft folder. Run from any MSYS2 shell.
export PATH="/mingw64/bin:$PATH"
here="$(cd "$(dirname "$0")" && pwd)"
gcc -O2 -Wall -Wextra -municode -mwindows "$here/launcher.c" -o "$here/../MarioCraft Launcher.exe" -lshell32 \
    && echo "OK: built MarioCraft Launcher.exe"
