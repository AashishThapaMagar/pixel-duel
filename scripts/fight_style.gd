extends Resource
class_name FightStyle
## Data-driven definition of one fighting discipline. Each of the match's four
## rounds is fought under a different style — swap the numbers/flags here (or
## make a new .tres in the Inspector) rather than branching all over player.gd.
## The handful of signature mechanics that truly need code (Karate's perfect
## block, Muay Thai's chip-through kicks, Boxing's no-kicks/combo bonus, MMA's
## punch-into-kick finisher) key off the flags below; everything else is pure
## numbers read straight into the matching @export var on Player.

@export var style_id: String = "karate"        # "karate" | "muay_thai" | "boxing" | "mma"
@export var display_name: String = "Karate"
@export var tagline: String = "Discipline and precision — every strike is a decision."
@export var accent_color: Color = Color(0.95, 0.8, 0.2, 1)

@export_group("Movement")
@export var move_speed: float = 260.0
@export var jump_velocity: float = -760.0

@export_group("Punch")
@export var punch_damage: int = 6
@export var punch_active_time: float = 0.08
@export var punch_total_time: float = 0.22
@export var punch_knockback: float = 220.0

@export_group("Kick")
@export var kick_damage: int = 12
@export var kick_active_time: float = 0.12
@export var kick_total_time: float = 0.38
@export var kick_knockback: float = 380.0
@export var kicks_disabled: bool = false   # Boxing: true — kick input throws a hook instead

@export_group("Hook (only thrown when kicks_disabled)")
@export var hook_damage: int = 9
@export var hook_active_time: float = 0.09
@export var hook_total_time: float = 0.26
@export var hook_knockback: float = 260.0

@export_group("Guard")
@export var block_chip_multiplier: float = 0.15
@export var kick_chip_bonus: float = 0.0        # Muay Thai: kicks chip through guard harder
@export var perfect_block_window: float = 0.0   # Karate: >0 enables parry-timing window

@export_group("Combo (Boxing)")
@export var combo_damage_step: int = 0          # extra damage per consecutive landed hit
@export var combo_max_stacks: int = 1
@export var combo_window: float = 0.6

@export_group("Finisher (MMA)")
@export var has_finisher: bool = false          # punch landed -> kick within finisher_window = bonus
@export var finisher_window: float = 0.35
@export var finisher_damage_mult: float = 1.5
@export var finisher_knockback_mult: float = 1.5
@export var finisher_cooldown: float = 1.5
