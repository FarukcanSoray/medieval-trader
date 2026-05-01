## Cheapest-viable map renderer: edges, nodes, neighbour outlines, name labels.
## Reads Game.world / Game.trader directly, queue_redraw on tick / state_dirty.
## No pan, no zoom, no input -- TravelPanel still drives travel.
class_name MapView
extends Node2D

const NODE_RADIUS: float = 16.0
const NODE_COLOR_DEFAULT: Color = Color(0.75, 0.75, 0.75)
const NODE_COLOR_CURRENT: Color = Color(0.95, 0.85, 0.30)
const NODE_OUTLINE_COLOR: Color = Color(0.9, 0.9, 0.9)
const NODE_OUTLINE_WIDTH: float = 1.0
const EDGE_COLOR: Color = Color(0.4, 0.4, 0.4)
const EDGE_WIDTH: float = 1.0
const TRAVEL_EDGE_COLOR: Color = Color(0.95, 0.85, 0.30)
const TRAVEL_EDGE_WIDTH: float = 5.0
const NAME_OFFSET: Vector2 = Vector2(20.0, -8.0)
const NAME_FONT_SIZE: int = 14
const NEIGHBOUR_OUTLINE_PADDING: float = 2.0
const NEIGHBOUR_OUTLINE_SEGMENTS: int = 32

func _ready() -> void:
	Game.tick_advanced.connect(_on_tick_advanced)
	Game.state_dirty.connect(_on_state_dirty)

func _draw() -> void:
	# Boot is silent re: cross-system signals; first frame may paint before
	# state lands. Bail rather than null-deref.
	if Game.world == null or Game.trader == null:
		return
	var world: WorldState = Game.world
	var trader: TraderState = Game.trader

	# 1. Edges. Highlight the in-flight travel edge if trader is en route.
	for edge: EdgeState in world.edges:
		var node_a: NodeState = world.get_node_by_id(edge.a_id)
		var node_b: NodeState = world.get_node_by_id(edge.b_id)
		if node_a == null or node_b == null:
			continue
		var color: Color = EDGE_COLOR
		var width: float = EDGE_WIDTH
		if trader.travel != null and _edge_matches_travel(edge, trader.travel):
			color = TRAVEL_EDGE_COLOR
			width = TRAVEL_EDGE_WIDTH
		draw_line(node_a.pos, node_b.pos, color, width)

	# 2. Nodes. Current node gets the highlight color; everything else default.
	# When travelling, no node is "current" -- the edge highlight carries the
	# location signal and trader.location_node_id is empty by P1 invariant.
	for node: NodeState in world.nodes:
		var fill: Color = NODE_COLOR_DEFAULT
		if trader.travel == null and node.id == trader.location_node_id:
			fill = NODE_COLOR_CURRENT
		draw_circle(node.pos, NODE_RADIUS, fill)

	# 3. Neighbour outlines (only when at rest -- mid-travel they'd misread as
	# "you can travel from here", which you can't until arrival).
	if trader.travel == null:
		for edge: EdgeState in world.outbound_edges(trader.location_node_id):
			var other_id: String = edge.b_id if edge.a_id == trader.location_node_id else edge.a_id
			var other: NodeState = world.get_node_by_id(other_id)
			if other == null:
				continue
			draw_arc(
				other.pos,
				NODE_RADIUS + NEIGHBOUR_OUTLINE_PADDING,
				0.0,
				TAU,
				NEIGHBOUR_OUTLINE_SEGMENTS,
				NODE_OUTLINE_COLOR,
				NODE_OUTLINE_WIDTH,
			)

	# 4. Name labels. Drawn last so they sit on top of nodes.
	var font: Font = ThemeDB.fallback_font
	for node: NodeState in world.nodes:
		draw_string(
			font,
			node.pos + NAME_OFFSET,
			node.display_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			NAME_FONT_SIZE,
		)

func _on_tick_advanced(_new_tick: int) -> void:
	queue_redraw()

func _on_state_dirty() -> void:
	queue_redraw()

# Undirected edge match against an in-flight travel.
func _edge_matches_travel(edge: EdgeState, travel: TravelState) -> bool:
	return (edge.a_id == travel.from_id and edge.b_id == travel.to_id) \
		or (edge.a_id == travel.to_id and edge.b_id == travel.from_id)
