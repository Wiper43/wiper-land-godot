# Wiper-Land — Game Design Document

*Living document. Last updated: 2026-04-16.*

---

## 30-Second Pitch

Wiper-Land drops you on a planet that doesn't care about you. Monsters hunt each other — and you. Night is terrifying. There are no quest markers, no tutorials, no safety nets. You craft your own spells, scavenge to survive, and push north into increasingly dangerous territory. Death is permanent. The community figures it out together.

---

## Three Pillars

| Pillar | Inspiration | Role in Wiper-Land |
|--------|-------------|-------------------|
| Exploration & freedom | Breath of the Wild | Traversal, awe at scale, climb-anything philosophy, dungeon puzzles, no hand-holding, art style |
| Randomized danger | Diablo | Procedural monster spawns with affixes, loot, gear progression, spell customization, push-into-harder-zones loop |
| Physics chaos | Fall Guys | Knockback combat, ragdoll, environmental kills, bouncy tutorial, platforming for loot |

The pillars interact: physics-driven combat meets a randomized ecosystem on a massive climbable sphere.

---

## Core Loop (Minute-to-Minute)

1. **Explore** — traverse the sphere, discover terrain, resources, dungeons
2. **Gather** — sticks, ore, food, crafting materials (nothing is infinite)
3. **Scout** — enemies are dangerous; observe before engaging
4. **Fight** — simple WoW Classic-style inputs, but physics-driven outcomes (knockback, environmental kills, monster stacking)
5. **Survive** — manage HP (no auto-heal), hunger, equipment, consumables
6. **Progress northward** — difficulty scales with latitude; mini-dungeons drop items that guide toward the north pole

The player must constantly decide: push deeper or retreat to resupply.

---

## Session Flow

### First 5 Minutes (Tutorial)
- Bouncy, playful training ground (Among Us vibes)
- Learn controls: move, jump, attack, bump into things
- Low stakes — get comfortable with physics

### Game Start
- Player spawns at the south pole
- BotW "leaving the cave" moment — overwhelmed by the scale of the world
- No direction given. Everything around is fun to do: climb trees, pick up sticks, explore
- The world feels alive without you

### After 10-30 Minutes
- Resources run out. HP doesn't regenerate. Character gets hungry
- Player realizes they can't kill everything for free
- Must conserve energy to reach the next village (save point / resupply)
- Tension sets in — this world is not friendly

### After an Hour
- Player understands the survival loop: prepare → push → retreat or die
- Crafting better gear from ore in hard-to-reach places
- Designing spells with meaningful tradeoffs
- Scouting enemies before every fight
- Exploring new territory requires real preparation

---

## World Design

### Geography
- **Spherical planet** — custom gravity, "up" is always away from planet center
- **South pole** = spawn / tutorial / safety
- **North pole** = endgame boss (players don't know it exists initially, like Minecraft's Ender Dragon)
- **Difficulty scales with latitude** — the further north, the harder it gets

### Biomes
- Multiple biomes across the sphere (minimum 2-3 for prototype)
- Each biome has distinct resources, enemy types, terrain challenges
- Long draw distance is critical — you should see the ecosystem from hilltops

### Day/Night Cycle
- **Day**: deadly monsters can spot you in the open
- **Night**: terrifying. Sound design drives fear. Players cower in the dark
- Both phases are dangerous in different ways

### Ecosystem
- Monsters hunt each other — predator/prey chains
- Players are NOT the apex predator. You are part of the food chain
- The world runs with or without you — nature takes its course
- Watching a living planet with no humans is part of the appeal

---

## Combat

### Philosophy
Simple inputs, emergent outcomes. The physics IS the combat.

### Style
- WoW Classic simplicity — easy to learn, depth comes from preparation and spell design
- No fancy attack animations needed — weight, knockback, and consequences matter
- Monsters require scouting before engagement

### Physics
- Heavy knockback on high-damage attacks — things get blown away
- Players can be pushed back too
- Smaller monsters become projectiles — body parts, blood, chaos
- Push monsters off bridges, into each other, off cliffs
- Monsters climb anything (slopes, walls, each other) with stamina
- Monsters can push players off edges — physics cuts both ways
- Physics must be near-perfect for the game to work

### Spell Crafting
- Players design their own spells with tradeoffs:
  - AoE vs single-target
  - Channeled (big hits) vs instant (fast hits)
  - Pushback vs raw damage
  - Boss damage vs crowd control
- Spell loadout balance is critical for surviving the unknown
- No "correct" build — different runs need different solutions

---

## Survival Systems

### Resources
- Nothing is infinite — sticks break, food spoils, gear degrades
- Ore found in mountains and hard-to-reach areas → craft stronger equipment
- Killing stronger opponents drops their loot
- Resource management is the core tension

### Health & Hunger
- No auto-heal
- Hunger system — must eat to survive
- Consumables are finite and must be managed

### Villages
- Save points / resupply stations
- Restore equipment and consumables
- Spaced out — reaching the next one is never guaranteed

---

## Death & Permadeath

### Life Line
- Safety net with a 24-hour cooldown
- On death: choose to resurrect at current location OR teleport to last village
- Prevents bullshit accidental deaths
- NOT a crutch — it's a one-time save per day

### Permanent Death
- Die with Life Line on cooldown = dead forever
- Character snapshot taken (equipped gear + stats)
- Dead character enters the Spirit World permanently

### Home Dance
- Free recall to last village at any time
- Costs nothing but you lose your position
- Strategic retreat mechanic — know when to pull out

### Spirit World (Multiplayer — Later)
- Dead characters exist permanently as spirits
- Can PvP other dead players
- Can accept duels from living characters
- Creates a persistent graveyard of past runs

---

## Progression

### Gear
- Found, crafted, and looted from enemies
- Ore → equipment crafting (better ore in harder/higher areas)
- Gear matters — pushing north unprepared is suicide

### Discovery
- Mini-dungeons contain items that subtly guide toward the north pole
- No explicit quest markers — players piece it together
- Community knowledge fills the gaps (wikis, forums, word of mouth)

### Dungeon Content
- Zelda-style puzzles inside dungeons
- Among Us-style platforming sections to reach loot chests
- Each dungeon is a self-contained challenge

---

## Art Style

- **BotW cel-shaded / stylized** — not realistic
- **Performance over fidelity** — always
- **Long draw distance** is more important than close-up detail
- Readable silhouettes at distance (you need to see the ecosystem happening)
- Nature-first aesthetic — no human civilization, players are visitors
- Cartoonish is fine if it runs well

---

## Target Audience

- Hardcore gamers who love permadeath (Escape from Tarkov, Hardcore Diablo, HC WoW Classic)
- Players who enjoy figuring things out without the game telling them
- Exploration-driven players who love BotW's open world
- Groups of friends (4-5) who want to adventure together

---

## Multiplayer Vision (Future)

- Designed for co-op groups of 4-5
- Friendly fire damage
- Singleplayer must work first — multiplayer is the ultimate form
- MMO is the dream, but not the current scope
- Spirit World PvP gives dead characters ongoing purpose

---

## Scope & Milestones

### A — Vertical Slice (Current Target)
- One biome
- Basic melee combat with physics knockback
- 1-2 enemy types in a functioning ecosystem
- Resource pickup (sticks, food, basic materials)
- HP + hunger system
- Day/night cycle
- One mini-dungeon with a puzzle
- Home Dance recall
- Death → Life Line system

### B — Playable Prototype (Next Target — ASAP)
- 2-3 biomes with different terrain/resources
- Spell crafting system (AoE vs single-target tradeoffs)
- 3-5 enemy types that hunt each other
- Basic crafting (ore → gear)
- Villages (save points / resupply)
- Difficulty scaling by latitude
- Sound design (night = terrifying)
- Platforming sections for loot
- Procedural monster spawns with affixes

### C — Full Vision (Long-Term)
- Complete sphere with north pole boss
- Full spell system
- Multiplayer co-op (4-5 players)
- Friendly fire
- Spirit World PvP
- MMO infrastructure
- Monster climbing (BotW-style climb-anything)
- Multiple dungeon types

---

## Design Principles

1. **The world doesn't care about you** — no hand-holding, no safety, no pity
2. **Physics is king** — simple inputs, emergent physics-driven outcomes
3. **Every run is different** — procedural spawns + permadeath = fresh adventures
4. **Preparation is gameplay** — scouting, resource management, spell loadout
5. **Community is the guide** — players teach each other, not the game
6. **Performance over beauty** — draw distance and ecosystem visibility matter most
7. **Simple combat, deep systems** — WoW Classic inputs with spell crafting depth
