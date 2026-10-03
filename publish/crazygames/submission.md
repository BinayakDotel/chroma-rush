# CrazyGames submission

Developer portal: https://developer.crazygames.com. Requirements: https://docs.crazygames.com/requirements/intro/

## Status

| Date | Event |
| --- | --- |
| 2026-10-02 | Submitted for Basic Launch (web build 1.0.0). |
| 2026-10-02 | Rejected: "The overall quality of the game does not yet meet the expectations of our platform". No further detail given. |

Resubmitting is allowed after "meaningful improvements". Before the next attempt:

- Ask Developer Support (in the portal) what fell short.
- Start the first run at once instead of opening the six-page how-to; their guidelines ask that new players land directly in play.
- Make the first minute faster and fuller.
- Bring back shadows and depth in the web build.
- Replace the synthesised sounds and music.
- Test on a low-end laptop (they expect smooth play on a 4 GB Chromebook) and on a real phone.

## What to upload

| Form field | File |
| --- | --- |
| Game files | every file in `build/web/` (or `build/upload/chroma-rush-web.zip` unzipped): all 9, including the two `*.worklet.js` files the sound needs |
| Cover, landscape 16:9 | `publish/covers/cover_landscape_1920x1080.png` |
| Cover, portrait 2:3 | `publish/covers/cover_portrait_800x1200.png` |
| Cover, square 1:1 | `publish/covers/cover_square_800x800.png` |
| Preview video, landscape | `publish/previews/preview_landscape_1920x1080.mp4` |
| Preview video, portrait | `publish/previews/preview_portrait_1080x1620.mp4` |

Name, category, tags, description and controls come from [../listing.md](../listing.md).

The cover upload shows a crop box with the top-left corner marked: CrazyGames lays its own labels there. The covers keep that corner clear, so leave the crop at the full image.

## Form answers

| Question | Answer |
| --- | --- |
| Launch type | Basic |
| Game engine | godot |
| Does your game save progress? | "No, the game does not need progress save". The game saves in the browser, but not through their SDK, and the other two options claim an integration it does not have. |
| The game supports mobile devices | Yes |
| Mobile orientation | Both |
| Online multiplayer | No |
| Supports CrazyGames muting audio through SDK | No |

## Limits

| | Limit | This build |
| --- | --- | --- |
| First download | 50 MB (20 MB to appear on the mobile homepage) | 12 MB compressed |
| Total size | 250 MB | 42.5 MB |
| Files | 1,500 | 9 |
| Preview video | 15 to 20 s, 50 MB | 18.7 s, 22 MB and 14 MB |

## For Full Launch (not built yet)

Basic Launch has no ads and no revenue. Full Launch, by invitation after Basic, needs:

- The CrazyGames SDK: gameplay start and stop events, and ads served through it. `scripts/services/ads_backends.gd` is the interface an ad backend plugs into.
- Progress saved through their Data module or their Automatic Progress Save.
- New players landing directly in gameplay.
