Implementation update: live matches now use seven complete-pose [arcade sprite atlases](../assets/sprites/fighter/arcade/README.md). Findings below document the previous renderer and the research that motivated replacement.

# Fighter movement: research and project diagnosis

Research date: 2026-09-16. Scope: KOF XII/XIII's illustrated sprites, Street Fighter V/6's character animation, Tekken 8's production workflow, and the current Godot project. This document distinguishes published production facts, observations from this repository, and proposed changes. It does not claim the walking is fixed.

The current approach has reached an art limitation: it deforms a single guard illustration to simulate a complete walk. Fixing joint lengths and reducing stride does not create the missing poses. My previous changes addressed individual defects but did not establish a convincing animation pipeline. The passing anatomy tests were not sufficient evidence of natural movement.

**What the reference games actually do**

| Reference | Published production method | Application to this project |
|---|---|---|
| KOF XII/XIII | SNK's XII production gallery shows a progression from 2D design through 3D modeling/motion and back to finished 2D artwork. XIII producer Kei Yamamoto describes posing and lighting 3D models, outputting 2D frames, then adding drawn expressions and shadows. | Build a coherent sequence of complete poses. A sprite renderer can be inexpensive because pose creation happens during asset production. |
| Street Fighter V/6 | Capcom's SFV Ed article describes motion capture and planning moves around startup timing. Capcom's SF6 technical account describes applying captured performance to CG characters and building Fighter Tool to adjust fighting-game character data. Ballet and street dance performances contributed to SF6 moves. | Motion needs both authored performance and gameplay timing. A good pose sequence must react promptly and agree with attack/contact timing. |
| Tekken 8 | Bandai Namco staff describe Maya modeling, MotionBuilder animation, and UE5 integration. They test costume deformation in motion and return to Maya to correct weights. The team explicitly discusses maintaining 60 FPS while building stage actions. | A rig must deform well throughout its motion, not only in its reference pose. Art and frame-time budgets need separate validation. |

Sources: [SNK XII production gallery](https://kofaniv.snk-corp.co.jp/info/15th_anniv/2d_dot/creation/), [XIII producer interview](https://blog.playstation.com/?p=63156), [Capcom's SFV Ed animation article](https://game.capcom.com/cfn/sfv/column/132209), [Capcom SF6 technical development account](https://www.capcom.co.jp/ir/english/data/oar/2023/development.html), [Tekken 8 staff interview published by Autodesk](https://blogs.autodesk.com/media-and-entertainment/2025/01/28/tekken-8-legacy-meets-innovation-with-the-combined-power-of-maya-and-unreal-engine/).

The Ed article was available through indexed excerpts; its full page could not be opened during this pass. The other linked accounts were opened. Tekken's detailed capture examples in that interview concern cinematics; they do not establish that every gameplay walk is motion-captured. These sources do not disclose universal walk-frame counts, blend durations, or movement formulas. KOF XIV and later also should not be conflated with XII/XIII's sprite workflow; [SNK identifies XIV as the numbered series' transition to 3D](https://www.snk-corp.co.jp/kof30th/en/poster/index.html).

**Why our characters still look unnatural**

`scripts/fighter_sprite_visual.gd` configures locomotion from `frame_data.frames[1]`, the guard picture. `scripts/fighter_locomotion.gd` divides it into two leg regions and an upper region, then moves the same textured vertices each sample. The arm/hand drawing stays essentially fixed while the legs move. Twisting a painted trouser region cannot supply a new view of the leg, a changed overlap, a turning shoe, or newly visible clothing. The code can keep mathematical bones connected while the image still looks rubbery.

The older `walk_cycles.png` is not a ready replacement. Visual inspection shows repeated or very similar extended-stride poses, with insufficient progression through the passing/contact poses to establish a convincing cycle. Switching it back on would not demonstrate that the problem is solved. The main fighter atlases also have only two nominal walking frames among sixteen frames covering many actions.

Our mathematical tests check lengths, foot positions, separation, and some transition continuity. They do not judge weight transfer, a readable silhouette, changing overlap, believable cloth, or how the loop feels while actually traveling. Those require moving-image review at gameplay scale.

**Why walking can feel delayed or uneven**

1. **Visual response:** `movement_blend` advances at 8 units/second. Going from 0 to 1 takes 125 ms, about eight updates at 60 Hz. The first update produces only about 4.9% of the full deformation after `smoothstep`. Movement can already be underway while the pose is still close to guard. This is a visual blend duration, not a measured 125 ms delay before input is accepted.
2. **Reduced movement speed:** the previous patch changed `WALK_SPEED_RATIO` from 0.65 to 0.40, a 38.5% reduction. For the base 260 speed this means 104 rather than 169 world units/second. It made movement slower without adding missing animation poses.
3. **Duplicate mesh work:** the controller calls `sync_pose()` from physics, which samples the mesh; the visual's `_process()` samples it again. At matching 60 Hz physics/render rates, two fighters can process about 127,440 vertices/second. This follows from 531 vertices per fighter/sample, with substantial repeated math and new arrays. It is not a GPU throughput measurement.
4. **Unused work:** the illustrated renderer also runs the procedural parent renderer's pose updates even though its `_draw()` is empty.
5. **Different clocks:** the body moves on the physics clock; gait travel/blends advance on the render clock. There is no explicit physics interpolation setting in this project. This is a jitter risk, especially at differing refresh rates, not proof of the user's particular display issue.

Godot distinguishes input lag, jitter, and performance stutter. Its documentation identifies mixed clocks and refresh-rate mismatch as jitter causes and warns that physics interpolation adds latency, explicitly calling out fighting games. A blanket interpolation or physics-rate change should therefore be measured, not assumed to fix everything. See [Godot's jitter, stutter, and input-lag guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html) and [interpolation setup and teleport handling](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html).

**Measured CPU cost**

Reproduce with:

```text
godot --headless --path . -s res://tools/locomotion_benchmark.gd
```

The diagnostic uses Godot 4.5.1, 20 warm-up iterations and 180 measured samples per fighter/case. Results go to `.godot/locomotion-benchmark.json`. The values below are from the initial run against the current working-tree animation code; they are wall-clock CPU microbenchmarks, not whole-game FPS or input-to-display latency.

| Fighter | One mesh sample, mean ms | Physics sync + render update, mean ms | One atlas frame selection, mean ms |
|---|---:|---:|---:|
| Anug | 0.743 | 1.501 | 0.017 |
| Ish | 1.020 | 2.078 | 0.020 |
| Sab | 0.885 | 1.872 | 0.018 |
| Bib | 0.815 | 1.665 | 0.019 |
| Abhi | 1.463 | 3.055 | 0.037 |
| Sup | 1.240 | 2.490 | 0.031 |
| Anant | 1.072 | 2.220 | 0.035 |

The simulated combined update's per-fighter 95th percentiles were 2.904–5.734 ms. For context, an entire 60 FPS frame has 16.67 ms available. The comparison demonstrates that dynamic deformation is materially more expensive than selecting existing frames on this machine. It does not prove the full game misses 60 FPS: GPU work, presentation, OS scheduling, other scene work, and real input hardware remain unmeasured. These three benchmark columns are separate measurements and must not be added together.

**Recommended replacement, based on the research**

For this illustrated, side-on game, use complete authored sprite cycles. A consistent 3D rig rendered to 2D and then painted over is the closest production analogy to KOF XIII; hand-authored 2D cycles are also viable. This is my recommendation for this project, not a requirement stated by the source games. Keep the existing character designs, but author the movement as motion assets instead of bending the guard image further.

Start with Anug and establish idle, forward combat step, backward combat step, forward run, start, stop, and reversal. Review the complete cycle with visible ground contacts. Let the lead foot initiate an advance and the rear foot initiate a retreat; the guard, pelvis, shoulders, and feet must participate coherently. Build a distinct run. Do not require movement to wait for an animation blend or a foot to finish its cycle.

A practical prototype target is 8–12 distinct poses per walk cycle, with explicit per-pose durations and more poses only where the motion needs them. This is an initial asset specification, not a claim about SNK/Capcom/Bandai frame counts. Every frame needs a stable root/ground reference; silhouette-based recentering can make a correct sequence wobble. Do not stretch a frame to make mismatched proportions fit. A 60 Hz simulation does not require 60 unique drawings per second.

Use one authoritative gameplay clock for movement and animation state. Playback selects preloaded frames using clip timing and traveled distance where appropriate. Match the authored stride to actual speed so the support foot does not skate. Define prompt, interruptible start/stop/reversal behavior. Preserve attack active-frame timing and hit-stop independently of cosmetic smoothing.

Remove duplicate sampling and unused procedural-body calculations when integrating the replacement. Profile a rendered two-fighter match before deciding on interpolation or frame-pacing changes. Maintain the existing combat tick rate while evaluating those changes; changing it also changes simulation behavior and needs separate validation.

**Completion criteria for the replacement**

- First eligible gameplay tick reacts to movement; the first displayed movement pose clearly acknowledges it. Attack, guard, and reversal do not wait on a long blend.
- Review walking, retreat, running, stopping, reversing, contact with a rival, and corners in motion, both facing directions, at gameplay scale. Check the loop seam and ground contact.
- Compare one finished fighter in a full match before extending the asset workflow to all seven. Retain the collision fixes and combat regressions.
- Measure real rendered frame-time distributions at 60 Hz and a higher-refresh display setting. Investigate spikes beyond the 16.67 ms frame budget. Measure input-to-display latency separately if delay remains; a headless test cannot certify it.
- Passing joint tests or looking acceptable in isolated screenshots is insufficient. The completed loop must look convincing and respond promptly in play.

This research pass adds a reproducible CPU diagnostic and this implementation brief. It does not replace the art or claim that the remaining visual problem is resolved.
