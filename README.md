> [!NOTE]
> Edits of this mod file are not permitted.
> You may submit a bug report via the Github Repo, however, the prefered method is through our discord this allows us to easily ask questions sould I need more evidence https://discord.gg/aDTTXAhE2m

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

- Dust Mechanics: Tune the implement-dust effects (plow, cultivator, combine, mower, baler, wheels and work particles) with a single global multiplier or turn them off entirely. 100% = engine default, 200% = mod default.

- Realistic Plowing: When one side of a tractor drops into a furrow, the lower wheels get a narrower physical collider and stronger suspension damping to reduce arcade-style bouncing.

- Realistic Wheel Physics: Slip-driven cultivator paint, terrain rut deformation, grip reduction on wet soil, wheel sink, anti-bounce suspension, viscous mud brake and slip-burst mud spray — full breakdown below.

- FarmKit HUD: On-screen wheel-slip percentage near the speedometer, colour-coded green / yellow / red.

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

<ins>**Realistic Wheel Physics:**</ins>

**A slip-driven physics layer that turns wheelspin on farmland into actual consequences:**

- Cultivator Paint: Spinning wheels on owned farmland paint cultivator texture under the contact patch.

- Terrain Deformation: Slip deforms the heightmap into proportional ruts, capped per cell so vehicles don't sink through the world. Depth scales with slip and wetness.

- Grip Reduction: Wet soil reduces lateral and longitudinal friction. The higher the wetness, the less grip.

- Wheel Sink: Under high slip, wheels sink slightly into the surface. Integrates with the base-game MudSystem field-sink updater when present.

- Anti-Bounce Suspension: When the wheel detects sustained deformation, suspension damping increases and displacement collision disables to stop arcade-style bouncing.

- Viscous Brake: Slip-proportional drag while spinning in mud — vehicles bog down naturally instead of revving free.

- Slip-Burst Mud Spray: Mud emission rate multiplies (up to 4×) during spin-outs, layered on top of the base Mud Physics.

- Smart Gates: Diff/4WD reduce damage, tire-type detection (street / forest / wide / twin / track) modulates grip and damage, heavy or wet vehicles lower the slip threshold, and the system reads VariableTirePressure when that mod is loaded.

The wheel slip percentage is displayed live by the FarmKit HUD near the speedometer. This system runs server-side on every driven wheel and is gated by the "Realistic Wheel Physics" toggle. Changes are synchronized across all players in multiplayer.