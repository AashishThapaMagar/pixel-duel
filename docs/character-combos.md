# Character combos and grapples

These are original game moves and tuning, not reproductions of Tekken frame data or real-world martial-arts instruction.

## Controls

P = punch (P1 F / P2 K), K = kick (P1 G / P2 L).

- P > P > K: punch starter, straight, character finisher.
- K > P > K: kick starter, character follow-up, character finisher.
- P > P > P: existing punch chain.
- Grapple: P1 H / P2 J, or press punch and kick together. Use at close range after approaching or baiting guard.
- Throw escape: tap grapple or punch + kick just before contact (0.16-second window).

Release directional inputs during a chain. Tap each attack as the previous hit connects. Each press requests one move; holding a button does not auto-combo. Only confirmed hits cancel. A blocked or missed attack must finish its recovery. Strike chains stop after three attacks and retain damage scaling. Grapples do not connect against airborne targets or opponents already in hitstun/blockstun, so strike-to-throw sequences require a fresh opening.

| Fighter | P > P > K finisher | K > P follow-up | Grapple | Identity |
|---|---|---|---|---|
| Anug | Goal-line clearance (front kick) | Keeper palm | Keeper catch | Space-making keeper |
| Ish | Flash rising fist (uppercut) | Flash body shot | Flash shoulder toss | Fast punch pressure |
| Sab | Anvil elbow | Iron body hook | Iron hip toss | Slower, hard-hitting clinch fighter |
| Bib | Relay side kick | Relay backfist | Relay ankle reap | Fast, long-reaching kicks |
| Abhi | Thunder overhand | Thunder body shot | Thunder clinch | Committed power strikes |
| Sup | Spiral heel (spinning kick) | Spiral palm | Spiral reap | Low and turning attacks |
| Anant | Crown knee | Crown backfist | Crown shoulder toss | Balanced boss toolkit |

F1 displays the selected fighters' names, actual move timing, and both sample routes. H/J is a shortcut for live 3D matches; the legacy scene also supports punch + kick. Touch controls include GRAB. AI uses the same stamina and hit-confirm rules and can choose close-range grapples.

## Research and design decisions

Reviewed on 2026-09-21. Research focused on accessible official guidance; this is not an exhaustive survey of every website.

- [Bandai Namco's Tekken 8 starter guide](https://en.bandainamcoent.eu/tekken/news/tekken-8-the-guide-start-playing) distinguishes punch, kick and paired-button throw inputs. Applied here as a simple punch/kick vocabulary with a paired-button grapple and an optional dedicated shortcut.
- [Official Special Style guide](https://en.bandainamcoent.eu/tekken/news/tekken-8-more-info-about-the-arcade-special-styles) describes recommended moves and combos assigned per character. Applied here as consistent easy inputs with different character-specific attacks and finishers; no automatic full string on one press.
- [Tekken 8 balance policy, May 2025](https://www.bandainamcoent.com/news/tekken-8-ver-2-01-balance-adjustment-policy) discusses risk/reward, excessive combo damage, and defensive sidesteps. Applied here as short capped chains, scaling, recovery, committed facing, and escapable short-range grabs.
- [Official replay feature](https://tk8.tekken-official.jp/en/mode/replay.php) highlights suggested combos and counterattacks as learning aids. Applied here through the F1 guide and sample chains rather than a new replay system.

Our timing, damage multipliers, reach, stamina costs, cancel rules and 0.16-second throw escape are design choices for this prototype. No claim of competitive balance is made. The existing procedural rigs provide distinct strike and grapple windups; cinematic paired throw animations and aerial juggling are not part of this change.

## Validation

`tests/character_combos_3d_test.gd` exercises both three-hit routes for all seven fighters using fresh input presses, actual 3D contact and uninterrupted combo tracking. It also tests guard-beating grabs for all seven, timed escape, range and airborne rejection, and denied cancels on block. Existing roster and fighting-system suites cover stamina, move availability and command-input behavior.
