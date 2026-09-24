> [!NOTE]
> Edits of this mod file are not permitted.
> You may submit a bug report via the Github Repo, however, the prefered method is through our discord this allows us to easily ask questions sould I need more evidence https://discord.gg/aDTTXAhE2m

<ins>**NX FarmKit**</ins> (ModHub v1.0.0.0)

A comprehensive field planning system and terrain-physics overhaul for Farming Simulator 25. View every field's material requirements at a glance, then drive over them knowing your wheels actually slip in mud, sink under load, deform the terrain into proportional ruts, and bog you down when you get stuck.

<ins>**Key Features**</ins>

- Field Overview: View every field on the map with size, fertilizer, lime, herbicide and seed requirements at a glance, grouped by farm.

- Material Coverage: Lime, mineral fertilizer, liquid fertilizer, manure, slurry, fermentation residue, herbicide and seed needs per field.

- Liquid Lime Support: The field dialog also shows liquid lime needs when the Liquid Lime mod is installed.

- Seed View: Toggle inside the same dialog to see per-crop seed liters for the selected field.

- Custom Map Fertilizers: Automatically detects mod-map fertilizers declared in the map's sprayTypes.

- Precision Farming Support: Reads live PF soil/pH/nitrogen/cover maps for accurate per-field estimates.

- Organic Nitrogen Mode: Switch the organic-fertilizer calculation between soil target and plant target (PF only).

- Multiplayer-Aware: Calculations run on the server with a fingerprinted cache and stream to clients on demand.

- Mud Physics: Dry/wet mud particles kick up off every driven wheel on soil contact, on or off field. Skips planters, seeders, plows and other tool categories.

- Ground Physics: Wheels flatten grass and meadow foliage off-field on your own land (field edges, meadows, yards), following the same speed curve as Speed-Based Crop Damage — creep through it and it stays standing. Flattened grass regrows; grassland fields and other farms' land are left alone.

- Dust Mechanics: Tune the implement-dust effects (plow, cultivator, combine, forage harvester, mower, baler, wheels and work particles) with a single global multiplier or turn them off entirely. 100% = engine default, 200% = mod default. Trailing dust ramps emission and lifespan down smoothly when work stops — no abrupt cut-off and no stuck-on emission from a stationary vehicle.

- Implement Dust Multiplier: A second slider that scales only towed/attached implement dust (plough, cultivator, sowing machine, roller, weeder, mower, mulcher, windrower, baler and combine/forager headers), on top of the global multiplier. Wheel kick-up and self-propelled combine/forager dust follow the global slider only.

- Realistic Plowing: When one side of a tractor drops into a furrow, the lower wheels get a narrower physical collider and stronger suspension damping to reduce arcade-style bouncing. Each wheel is also checked on its own: one riding below the surrounding ground (in the furrow) gets a thin collider so the furrow walls can't catch it.

- Realistic Wheel Physics: Speed-and-scrub-aware terrain rut deformation, foliage-only crop damage in the wheel track, grip reduction on wet soil, wheel sink, anti-bounce suspension, throttle-gated viscous mud brake, engine bog when stuck, and slip-burst mud spray. Diff lock/4WD and wide or track tyres reduce the damage; heavy or wet conditions make it start sooner.

- Realistic Engine Mode: Engine revs climb as the wheels sink and spin out on field, and engine torque sags under a working plough, cultivator or sowing machine — scaled by working width, soil wetness and slope, and restored when the implement is raised or detached.

- Realistic Hauling: Trailers lose their load when tipped past 15° (sharp turns, terrain rolls, rollovers). A closed tarp gives 15° of extra headroom but gives way past 60°. About 70% of the spilled load lands as a pickupable heap; the rest is lost. When tipping on purpose, a stationary tip piles material under the chute and a fast tip throws it further. Solid loads only (grain, fertilizer, lime, manure, silage, etc.).

- Combine Straw Refeed: A threshing combine with its header lowered over an existing straw windrow picks the straw back up, runs it through the machine (about 2 s) and drops it out of the rear swath again. With the chopper on, it is chopped and spread instead.

- Speed-Based Crop Damage: Wheels flatten crops based on speed instead of all-or-nothing. Below 5 km/h crops survive; the chance climbs smoothly to near-certain around 40 km/h. Tyre width, steering, ground wetness and vehicle weight raise it; row-crop (care) tyres never flatten crops, as in the base game. Each ground patch has a fixed toughness, so damage is patchy and repeated slow passes don't wipe it out. Only active while the game's Crop Destruction setting is on. Grass and meadow are never flattened by the base game; Ground Physics handles those off-field with the same speed curve.

- Road Water Spray: Every wheeled vehicle and trailer throws water spray off its tyres on wet asphalt, concrete, bridges and other object roads. It starts around 12 km/h and builds with speed, road wetness and falling rain; wider tyres throw more. It sprays the right way when reversing and stays off on soil (the mud spray covers that) and snow. Visual only, so no extra multiplayer traffic.

- Realistic Engine Sound Distance: Engine, gearbox and retarder sounds carry 180–380 m depending on engine power and fade the way real sound spreads, with a smooth fade-out at the edge. Distant engines lose their high end, engines behind hills, buildings or other solid objects are muffled further, and passing vehicles shift pitch (Doppler). Turning it off restores the game's original ranges.

- Neighbours: Up to 10 neighbour farmers (hard limit) take open field contracts, bring the lease machines to the field, hitch up and put a helper to work. Their seed, fertiliser, herbicide and fuel are free, harvesters never stop full, and once the job is done the contract closes and the machines leave. They always leave at least 3 open contracts for you, never start a job right in front of you, never take your last free helpers and don't count against your helper limit. Their pay goes to their own hidden farm. Off by default — each active neighbour costs some performance.

- FarmKit HUD: Compact readout strip docked to the left of the time/date display in the top-right. Shows colour-coded wheel slip %, ground wetness %, current precipitation %, and a countdown to the next or current rain/snow/hail event with its type. A red [STUCK] badge appears when the controlled vehicle is bogged hard enough to need a tow.

- In-Game Settings Toggles: Every physics feature can be enabled or disabled live in Options → General Settings.

- Multi-Language Support: Available in 3 languages (English, Deutsch, Français).

**Usage:**

Press Right Shift + F to open the FarmKit dialog.

**Settings Menu**

Access settings via ESC → Settings → General Settings → NX FarmKit

| Setting | Type | Default |
|---|---|---|
| Ground Physics (mud spray, ruts, wheel sink, off-field foliage) | On / Off | On |
| Dust Mechanics | On / Off | On |
| Dust Multiplier | 50 % – 500 % | 200 % |
| Implement Dust Multiplier | 50 % – 500 % | 100 % |
| Realistic Plowing | On / Off | On |
| Realistic Wheel Physics | On / Off | On |
| Realistic Engine Mode | On / Off | On |
| Realistic Hauling | On / Off | On |
| Combine Straw Refeed | On / Off | On |
| Speed-Based Crop Damage | On / Off | On |
| Road Water Spray | On / Off | On |
| Realistic Engine Sound Distance | On / Off | On |
| Neighbours | Off, 1 – 10 | Off |
| FarmKit HUD | On / Off | On |

Settings are persisted to `modSettings/FS25_FarmKit_Settings.xml` and synchronized across all players in multiplayer.