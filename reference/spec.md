# Writing a spec

A spec is a Luau module returning plain data: the poses of an R15 character at a few key frames,
in degrees. The forge turns it into a `KeyframeSequence` (`.rbxm`), checks it, and draws it.

```lua
--!strict
-- What the animation shows, how long, which part of the body (a comment: future you will thank you).

return {
	name = "HitReact", -- the file's name, without .luau
	length = 18, -- last frame (60 frames per second)
	keys = {
		{ frame = 0, ease = "Out", pose = { UpperTorso = { x = 0, y = 0 }, Head = { x = 0, y = 0 } } },
		{ frame = 2, ease = "InOut", pose = { UpperTorso = { x = 10, y = -5 }, Head = { x = 10, y = 4 } } },
		{ frame = 18, ease = "Linear", pose = { UpperTorso = { x = 0, y = 0 }, Head = { x = 0, y = 0 } } },
	},
}
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | Must match the file name. Also the animation's name on Roblox. |
| `length` | number | Last frame. The last key sits on it. 60 frames per second. |
| `keys` | `{ Key }` | In frame order. Every key poses the same joints. |
| `loop` | boolean? | A looping animation. Its last key repeats its first pose. |
| `marker` | `{ name, frame }`? | A named keyframe marker (`GetMarkerReachedSignal`), e.g. the frame a hit lands. |
| `flow` | boolean? | One continuous curve through every key instead of separate eased moves (below). |
| `overlap` | `{ after, lags }`? | Keys after frame `after` (except the last) reach each part `lags[part]` frames later. |
| `airborne` | boolean? | Played in the air: the preview does not check the feet against the ground. |

A key: `{ frame, ease, velocity, pose }`. `ease` is required unless the spec flows. `pose` maps a
part name to a rotation `{ x, y, z }` in degrees (missing axes are 0). The pelvis (`LowerTorso`)
also takes an offset in studs: `px`, `py`, `pz`.

## Joints and axes

Each rotation is the joint's own, from the rest pose (standing, arms down). Only the parts a spec
poses are animated: an upper-body spec leaves the legs to the game's walk.

| Part | Joint | `x` | `y` | `z` |
| --- | --- | --- | --- | --- |
| `LowerTorso` | root | pitches the whole body (90: lying on the back) | turns the body toward its left | rolls it toward its left |
| `UpperTorso` | waist | leans back (negative: forward) | turns toward the character's left | bends toward its left |
| `Head` | neck | looks up (negative: down) | turns left | tilts toward its left |
| `RightUpperArm`, `LeftUpperArm` | shoulder | raises the arm forward | turns the arm around itself | right: lifts it outward; left: needs a negative `z` |
| `RightLowerArm`, `LeftLowerArm` | elbow | bends the forearm up | | |
| `RightHand`, `LeftHand` | wrist | tips the hand up | rolls the held item toward the left | |
| `RightUpperLeg`, `LeftUpperLeg` | hip | swings the thigh forward | | right: spreads the leg outward; left: needs a negative `z` |
| `RightLowerLeg`, `LeftLowerLeg` | knee | negative: bends | | |
| `RightFoot`, `LeftFoot` | ankle | lifts the toes | | |

`py` lowers the pelvis (negative, in studs) to kneel, sit or lie down. Standing, the pelvis is at
2.45 studs, the head's centre at 4.85, an ankle at 0.25: the ground is at 0.

An item held in the right hand (a wand, a sword, a tool) points along the hand's -Z axis: arm
hanging, it points ahead; arm raised forward, it points up.

### Two rules learned the hard way

- A positive `x` on the head or the torso looks up or leans back. To bow or look down, use a negative `x`.
- An arm goes above the head by the side (`z`), never by swinging forward past 140 degrees (`x`):
  that turns it inside out.

## Timing

- **Eased** (default): `ease` shapes the move from a key to the next one. `In` accelerates (a strike),
  `Out` decelerates (a landing), `InOut`, `Linear`. Each move stops on its key: to pass through a key
  without stopping, ease `In` into it and `Out` of it.
- **Flowing** (`flow = true`): one continuous curve through every key, sampled every 2 frames. The
  motion only stops on a key with `velocity = "stop"` (the first and last keys by default) and never
  overshoots a key. `velocity = "impact"` arrives at full speed and leaves along the next move (a body
  hitting the ground, a beat of a dance). The rhythm comes from the gaps between keys: tighter and
  tighter keys accelerate, like a fall.
- **Overlap**: the torso follows the hips, the arm the torso, the hand the arm. Without it every joint
  starts and stops at once, which looks mechanical. Typical lags: 1 to 3 frames, growing toward the
  extremities (`UpperTorso = 1, RightUpperArm = 2, RightHand = 3`).
- **Holds** read the action: after a strike, keep the pose 6 to 10 frames before recovering.

## Sharing poses

A spec is code: share poses between specs with a module next to the specs folder (e.g.
`poses/Kneel.luau`, required as `require("../poses/Kneel")`), or build keys with functions (see
`examples/specs/Dance.luau`). Only the files in the specs folder are animations.
