# Chroma Rush

**Match your colour, smash through the gates, race across five hand-crafted worlds.**

Chroma Rush is a colour-matching endless runner built with Godot 4. Race down a twisting road, switch your vehicle to the colour of each gate before you hit it, dodge rocks, jump hurdles and keep your fuel tank topped up. Fill the Prism meter and go into Overdrive to smash through everything in your way.

![Five worlds of Chroma Rush](docs/screenshots/hero-worlds.jpg)

## Screenshots

| Meadow | Glacier | Canyon |
| --- | --- | --- |
| ![Meadow](docs/screenshots/gameplay-meadow.jpg) | ![Glacier](docs/screenshots/gameplay-glacier.jpg) | ![Canyon](docs/screenshots/gameplay-canyon.jpg) |
| **Volcano** | **Solar System** | **Home (landscape)** |
| ![Volcano](docs/screenshots/gameplay-volcano.jpg) | ![Solar System](docs/screenshots/gameplay-space.jpg) | ![Home screen in landscape](docs/screenshots/home-landscape.jpg) |

### Drivers

Every world has its own vehicle and driver. Painted panels (and the penguin's beanie) change to the colour you have selected.

![Fox, penguin, gecko, rock golem and alien drivers](docs/screenshots/characters.jpg)

### On a phone

Home, in-run HUD, results, shop, how to play and settings, in portrait:

![Phone screens](docs/screenshots/phone-screens.jpg)

## How to play

Each gate has a **colour and a shape**: red circle, yellow triangle or blue square. Be the same colour when you reach it, or you crash. The shapes mean the game never relies on colour alone.

| Obstacle | What to do |
| --- | --- |
| Colour gate | Switch to the gate's colour before you reach it |
| Block (rock, ice, cactus, meteor) | Change lanes to get around it |
| Hurdle (log, snowdrift, fence, lava, laser) | Jump over it |
| Fuel pickup | Drive through it; the tank drains as you go |

Passing gates and grabbing orbs fills the **Prism meter**. When it is full, trigger **Prism Overdrive** for five seconds of speed and invincibility.

### Controls

| Action | Touch | Keyboard |
| --- | --- | --- |
| Change lane | Swipe left / right | A / D or arrow keys |
| Jump / slam down | Swipe up / down | W / S or arrow keys |
| Pick a colour | Tap a colour button | J K L or 1 2 3 (Space cycles) |
| Prism Overdrive | Tap PRISM | Shift or E |
| Pause | Pause button, back button | Esc or P |

## Features

- **Five worlds**: Meadow, Glacier, Canyon, Volcano and Solar System, each with its own sky, scenery, landmarks, obstacles, gate arch, vehicle and driver.
- **Readable for everyone**: one colour set in every world, chosen to stay distinct under protanopia, deuteranopia and tritanopia, plus a shape per colour.
- **Endless and stable**: the track is generated as you drive, with bounded memory and a floating origin, so a 60 km run uses the same memory as a 1 km run.
- **Full navigation**: home screen with world picker, how to play, pause, results, settings, shop, and the Android back button.
- **Progression**: shards from orbs and distance unlock new worlds; best score per world; lifetime stats.
- **Accessibility and comfort**: colour shapes, reduced motion, separate music and sound volume, vibration toggle, three graphics levels.
- **Built to be tiny**: every model, texture, sound and the music are generated in code. The whole game pack is about 700 KB.

## Worlds

| World | Driver and vehicle | Hurdle | Unlock |
| --- | --- | --- | --- |
| Meadow | Fox in a go-kart | Mossy log | Free |
| Glacier | Penguin on a bobsled | Snowdrift with ice spikes | 500 shards |
| Canyon | Gecko in a dune buggy | Ranch fence | 1,500 shards |
| Volcano | Rock golem in a monster truck | Lava fissure | 3,500 shards |
| Solar System | Alien astronaut in a star racer | Laser fence | 6,000 shards |

## Business model

Free to play with opt-in rewarded ads (second chance, double shards), rare interstitials that can be removed, and one-time purchases: **Supporter Pack** ($5.99), **World Pass** ($3.99) and **No Ads** ($2.99). Nothing for sale changes difficulty or score.

Product IDs, ad rules and prices live in `scripts/services/store.gd`, `scripts/services/ads.gd` and `scripts/services/economy.gd`.

## Project layout

```
main.tscn                 Game scene: world, sun, track, player, camera, UI, audio
scripts/
  game.gd                 Game flow, scoring, collisions, input, rewards
  track.gd                Endless path, road chunks, rows, orbs, fuel, floating origin
  player.gd               Vehicle movement and animation (steering, springy parts, trail)
  vehicles.gd             The five vehicles and drivers, built from code
  obstacles.gd            Blocks, hurdles, gate arches and gems
  scenery.gd, props.gd    Roadside ground, props and distant landmarks
  themes.gd, defs.gd      World definitions, colours and tuning
  audio.gd                Synthesised sound effects and music
  services/               Settings, Profile (save), Store (IAP), Ads, Economy
  ui/                     UI toolkit, icons, screens and navigation
  dev/                    Developer harness, flow test, icon renderer (not shipped)
shaders/                  Sky, road, gate panel, hazard, orb, outline, planet
fonts/                    Lilita One and Nunito, with their licences
icons/                    App icon source and rendered store / launcher icons
docs/screenshots/         Images used in this README
images/                   Style reference images (not shipped)
```

## Running

1. Install [Godot 4.7](https://godotengine.org/download).
2. Open `project.godot` in the editor and press Play, or run `godot --path .` from the project folder.

On desktop, debug builds use a test store and test ads, so the shop, second chance and double shards can be tried without a phone.

## Testing

A developer harness plays the real game with an autopilot. It saves to `user://dev`, never to your real progress.

```sh
# End-to-end flow checks: tutorial, pause, crash, revive, rewards, unlocks, purchases, settings
godot --headless --path . res://scripts/dev/dev.tscn -- --flow-test

# Memory soak: 60 km without crashing, printing memory every minute
godot --headless --path . res://scripts/dev/dev.tscn -- --world=meadow --autoplay --god --soak=60000 --time-scale=6 --report-every=60

# Screenshots of a world or a screen
godot --path . --resolution 720x1560 res://scripts/dev/dev.tscn -- --world=canyon --autoplay --god --tutorial-done --shots=10
godot --path . --resolution 720x1560 res://scripts/dev/dev.tscn -- --world=glacier --tutorial-done --screen=shop --shots=2
```

Screenshots need a window, so they briefly open the game on screen. See the top of `scripts/dev/dev_harness.gd` for every option.

## Building for release

Export presets for macOS, Android (AAB) and iOS are in `export_presets.cfg`; the harness, tests and reference images are excluded from every build. Before a store release:

- Install the Android and iOS export templates (Editor > Manage Export Templates).
- Add the [Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing), [StoreKit 2](https://github.com/godot-sdk-integrations/godot-storekit2) and [AdMob](https://github.com/godot-sdk-integrations/godot-admob) plugins and enable them in the presets.
- Create the products in Play Console and App Store Connect with the IDs in `scripts/services/store.gd`.
- Put the AdMob ad unit IDs in `scripts/services/ads_admob.gd` and the privacy / support links in `scripts/ui/screens/settings_screen.gd`.
- Set up the Android keystore and the Apple team ID.

To regenerate the icons after editing `icons/icon.svg`:

```sh
godot --headless --path . -s res://scripts/dev/render_icons.gd
```

## Credits

- Made with [Godot Engine](https://godotengine.org) (MIT licence).
- Fonts: [Lilita One](https://fonts.google.com/specimen/Lilita+One) and [Nunito](https://fonts.google.com/specimen/Nunito), under the SIL Open Font License (see `fonts/`).
- The files in `images/` are third-party style references used during development; they are not part of the game and are not included in any build.
