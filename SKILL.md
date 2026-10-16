---
name: roblox-anim-forge
description: Create, check and publish R15 animations for Roblox from code. Use when a Roblox project needs a character animation (an attack, a cast, a hit reaction, an emote, a kneel, a loop) and no animator is at hand, or to fix an existing generated one. You write the poses as Luau data, build .rbxm KeyframeSequences with Lune, look at the rendered PNG contact sheet, and iterate until it reads well.
---

# roblox-anim-forge

You cannot see an animation play, but you can see its poses: the forge draws them on an R15 rig
into a PNG and tells you, in numbers, where the hands, feet and held item are and what goes through
the ground or another limb. Write, build, look, fix: never deliver an animation you have not looked at.

## Setup in a project (once)

Needs [Lune](https://github.com/lune-org/lune) 0.10.x (`rokit add lune-org/lune@0.10.5`).

1. Add the forge, preferably as a git submodule: `git submodule add https://github.com/Volubal/roblox-anim-forge tools/anim-forge`.
2. Copy `templates/anim.luau` next to a new `specs/` folder (e.g. `tools/animations/anim.luau`).
   Set in it the forge's path (relative to the runner), the specs folder (relative to the project
   root), where the `.rbxm` files and the previews go, and the bundle's name.
3. Ignore the previews folder in git; commit the specs and, if the project wants them, the `.rbxm`.

Commands, from the project root (`<runner>` is the runner's path without `.luau`):

```bash
lune run <runner> list
lune run <runner> build [Name]              # .rbxm + a check line per key
lune run <runner> preview Name [frame ...]  # PNG contact sheet of the keys (or of those frames)
lune run <runner> preview Name --sweep      # checks every frame, prints only the wrong ones
lune run <runner> publish Name ...          # Open Cloud upload, prints rbxassetid://...
```

## The loop

1. **Ask what the animation is for** if it is not clear: what triggers it, how long it may last,
   whether the character keeps walking (upper body only) or stands still (whole body), whether it
   loops, and the frame the game needs a marker on (the hit, the release).
2. **Write the spec** in `specs/<Name>.luau`: read [reference/spec.md](reference/spec.md) first (fields,
   joints and axes, timing). Start from the closest example in `examples/specs/`. Name each pose as
   a local (`READY`, `WINDUP`, `STRIKE`) with a comment saying what the body does, and open the file
   with a comment describing the whole animation.
3. **Build it**: `lune run <runner> build Name`. Read each key's line: `item ahead/left/up` is where
   the right hand's item points (on a strike's marker frame, `ahead` should be near 1); for a whole-body
   spec, the heights of the pelvis, head, knees, ankles and wrists (ground at 0, a standing ankle at
   0.25, a knee on the ground near 0.45).
4. **Look at it**: `lune run <runner> preview Name`, then read the PNG with your image tool. One column
   per key, four views each (front, the character's right side, top, three-quarter). Right limbs red
   and orange, left blue and cyan, the face lighter with eyes, the held item yellow with a white tip,
   the ground a grey ring. Problems are written in red: `A IN B` (a part sunk into another),
   `Part 0.13 UNDER GROUND`. Check that each pose says what it should, seen from the side too.
5. **Sweep it**: `lune run <runner> preview Name --sweep`. Between keys, limbs can pass through the
   ground or the body even when every key is clean. Preview the frames it names (`preview Name 11 12`)
   and add or move a key to fix them.
6. **Iterate** on the poses and timing until the sheet reads well and the sweep is clean (or what
   remains is understood and acceptable: say so).
7. **Hand it over**: tell the user what the animation does, its length, and where the `.rbxm` is.
   Publishing needs their Open Cloud key (below); otherwise they insert the `.rbxm` in Studio.

## Rules that save time

- A positive `x` on the head or torso looks **up** or leans **back**. Bowing is negative `x`.
- Raise an arm above the head by the side (`z`), never past 140 degrees forward (`x`): it turns inside out.
- Left shoulders and left hips mirror the right ones on `z` (negative to spread).
- Eased keys stop on every key: a movement passing through a key needs `In` before it and `Out` on
  it, or use `flow = true`.
- Motion looks alive with overlap (torso, then arm, then hand, a frame or two apart), anticipation
  (a small move the other way first), a hold after the action, and a short settle at the end.
- Upper-body animations pose no leg and no `LowerTorso`, so they blend with walking. Whole-body
  ones pose every joint and lower the pelvis with `py` to bend the knees (check the ankle heights).
- A looping animation's last key repeats its first pose exactly, and sets `loop = true`.
- Do not trust a single view: a pose fine from the front can be wrong from the side.
- Keep values round and commented; the user (or an animator) will tweak them by hand.

## Publishing

`publish` uploads the built `.rbxm` through the Open Cloud Assets API and prints the asset id. It
reads from the environment: `ROBLOX_API_KEY` (scopes `asset:read` and `asset:write`) and the owner,
`ROBLOX_GROUP_ID` or `ROBLOX_USER_ID`. Never print, log or commit the key. Without a key: in Studio,
insert the `.rbxm` (or the bundle) into `ServerStorage`, right-click the `KeyframeSequence` > Save to
Roblox.
