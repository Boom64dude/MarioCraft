# Third-party notices

MarioCraft's own code is MIT licensed (see `LICENSE`, which also says exactly what it covers).

MarioCraft is distributed as source changes (the `patches` folder) to two other projects. MarioCraft
doesn't include either of them: the installer downloads both from their own repositories.

| Project | Version | Where | License |
|---|---|---|---|
| sm64coopdx | v1.5.1 (`8cd6e59`) | https://github.com/coop-deluxe/sm64coopdx | None published (see below) |
| SkyCraft | v0.1.2 (`bfcaf17`) | https://github.com/chasmlol/SkyCraft | MIT, see `licenses/SkyCraft-LICENSE.txt` |

**SkyCraft:** `patches/skycraft.patch` modifies SkyCraft and contains portions of it. SkyCraft's MIT
License (`licenses/SkyCraft-LICENSE.txt`) applies to those portions.

**sm64coopdx:** sm64coopdx doesn't publish a license, and it is based on the Super Mario 64
decompilation (https://github.com/n64decomp/sm64). `patches/sm64coopdx.patch` adds MarioCraft's own
files (MIT, ours) and makes small changes to a few existing sm64coopdx files, hooking them into
MarioCraft. Those existing files, and the lines of them the patch shows, remain sm64coopdx's, under
its authors' terms; MarioCraft claims no rights in them. MarioCraft follows the practice of
sm64coopdx mods: it ships only its own changes, and the player builds the game from sm64coopdx's
repository and their own ROM.

**Downloaded by the Prism Launcher setup** (`launcher/setup-prism.ps1`), each checked against a
pinned SHA-512 hash:

- Fabric API 0.161.0+26.3: https://modrinth.com/mod/fabric-api (Apache License 2.0)
- e4mc 6.2.2: https://modrinth.com/mod/e4mc (see its page)

**Game data:** none is included. Super Mario 64's data comes from the player's own ROM at build time.
Minecraft, its assets and C418's music come from the player's own Minecraft: Java Edition, through
Prism Launcher.
