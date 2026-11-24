class_name SocialRules
extends Resource
## How pawns get along: who counts as company, how opinions and the social need change,
## and what they do to mood. All numbers are placeholders.

## Pawns this many cells apart or closer (either way) are in each other's company.
@export var near_cells: int = 2
## A pair's rolled chemistry runs from -this to +this.
@export var chemistry_range: float = 0.5
## Added to a pair's chemistry for each trait they share, and taken off for each pair of
## opposite traits (same group, different trait) between them.
@export var shared_trait_bonus: float = 0.25
@export var opposite_trait_penalty: float = 0.25
## Opinion points per shop minute in company, times the pair's chemistry.
@export var opinion_per_minute: float = 1.0
## Social gained per shop minute in company of someone they feel neutral about (more for
## friends, less, or a loss, for people they dislike), times their social need.
@export var company_per_minute: float = 1.0
## Social lost per shop minute alone, times their social need.
@export var alone_drain_per_minute: float = 0.2
## Opinion that makes a friend, or (negative) a rival.
@export var friend_at: float = 50.0
@export var rival_at: float = -50.0
