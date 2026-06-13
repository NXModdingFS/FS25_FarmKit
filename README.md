> [!NOTE]
> Edits of this mod file are not permitted.
> You may submit a bug report via the Github Repo, however, the prefered method is through our discord this allows us to easily ask questions sould I need more evidence https://discord.gg/aDTTXAhE2m

<ins>**Credits**</ins> 

- Tubez47 Realistic Load Spill

<ins>**NX FarmKit**</ins> (ModHub v1.0.0.0)

A comprehensive field planning system and terrain-physics overhaul for Farming Simulator 25. View every field's material requirements at a glance, then drive over them knowing your wheels actually slip in mud, sink under load, deform the terrain into proportional ruts, and bog you down when you get stuck.

<ins>**Key Features**</ins>

- Field Overview: View every field on the map with size, fertilizer, lime, herbicide and seed requirements at a glance, grouped by farm.

- Material Coverage: Lime, mineral fertilizer, liquid fertilizer, manure, slurry, fermentation residue, herbicide and seed needs per field.

- Seed View: Toggle inside the same dialog to see per-crop seed liters for the selected field.

- Custom Map Fertilizers: Automatically detects mod-map fertilizers declared in the map's sprayTypes.

- Precision Farming Support: Reads live PF soil/pH/nitrogen/cover maps for accurate per-field estimates.

- Organic Nitrogen Mode: Switch the organic-fertilizer calculation between soil target and plant target (PF only).

- Multiplayer-Aware: Calculations run on the server with a fingerprinted cache and stream to clients on demand.

- Mud Physics: Dry/wet mud particles kick up off every driven wheel on soil contact, on or off field. Skips planters, seeders, plows and other tool categories.

- Ground Physics: Wheels flatten supported grass/meadow foliage on field edges, meadows and yards — without damaging foreign-field crops.

- Dust Mechanics: Tune the implement-dust effects (plow, cultivator, combine, forage harvester, mower, baler, wheels and work particles) with a single global multiplier or turn them off entirely. 100% = engine default, 200% = mod default. Trailing dust ramps emission and lifespan down smoothly when work stops — no abrupt cut-off and no stuck-on emission from a stationary vehicle.

- Realistic Plowing: When one side of a tractor drops into a furrow, the lower wheels get a narrower physical collider and stronger suspension damping to reduce arcade-style bouncing.

- Realistic Wheel Physics: Speed-and-scrub-aware terrain rut deformation, foliage-only crop damage in the wheel track, grip reduction on wet soil, wheel sink, anti-bounce suspension, throttle-gated viscous mud brake, engine bog when stuck, and slip-burst mud spray — full breakdown below.

- FarmKit HUD: Compact readout strip docked to the left of the time/date display in the top-right. Shows colour-coded wheel slip %, ground wetness %, current precipitation %, and a countdown to the next or current rain/snow/hail event with its type. A red [STUCK] badge appears when the controlled vehicle is bogged hard enough to need a tow.

- In-Game Settings Toggles: Every physics feature can be enabled or disabled live in Options → General Settings.

- Multi-Language Support: Available in 3 languages (English, Deutsch, Français).

**Usage:**

Press Right Shift + F to open the FarmKit dialog.

**Settings Menu**

Access settings via ESC → Settings → General Settings → NX FarmKit

| Setting | Type | Default |
|---|---|---|
| Mud Physics | On / Off | On |
| Ground Physics | On / Off | On |
| Dust Mechanics | On / Off | On |
| Dust Multiplier | 25 % – 400 % | 200 % |
| Realistic Plowing | On / Off | On |
| Realistic Wheel Physics | On / Off | On |
| FarmKit HUD | On / Off | On |

Settings are persisted to `modSettings/FS25_FarmKit_Settings.xml` and synchronized across all players in multiplayer.
