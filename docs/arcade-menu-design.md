# Arcade menu and character selection

Reference research: Tekken 3 screenshot collections surfaced a large title treatment, a concise mode list, paired fighter portraits, and a compact portrait roster. Visual references: [Arcade Fighter gallery](https://www.arcade-fighter.com/af/juegos/tekken-3.php), [character-select screenshot archive](https://www.vizzed.com/games/tekken-3-psx-playstation-35813-game-characters). These informed the layout, not copied assets. Some other archives and manual hosts did not allow full-page retrieval.

The implementation keeps WHO WON?, its original fighters, and its existing modes. A deep blue backdrop, warm outlined title and silver mode labels establish the home screen. Up/Down changes modes; Enter opens character selection. Settings, arena previews and move guidance remain accessible.

Character selection displays all seven cards inside 960x540, two large live 3D fighter previews, player markers and readiness controls. Portraits render the actual gameplay mesh with dedicated camera and lighting, so a selection matches its in-game appearance. No new hand-authored character meshes, imported Tekken artwork or music are included.

P1 selects with A/D and confirms with F; P2 selects with Left/Right and confirms with K. Enter starts after confirmation. Mouse selection uses the active player tab. AI modes pre-confirm the CPU; Arcade and Story preview the actual first rival and prevent overriding that automatic selection. Story prologue and arcade progression run after character confirmation.

Validation: `tests/arcade_menu_test.gd` covers every card fitting, selection/preview agreement, readiness and entry into all four modes. `--capture` saves `.godot/arcade-main-menu.png` and `.godot/arcade-character-select.png`. Existing UI, roster and story tests now pass through selection before validating match behavior.
