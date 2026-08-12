class_name SceneObj
extends RefCounted


var mat_key: String
## shape tag, which is how a level demands its own element on the answer path
var kind: String
## optic axis, only meaningful for a birefringent material. It follows the
## body's own rotation, so turning a crystal turns its axis
var axis: float = 0.0


func intersect(_p: Vector2, _d: Vector2) -> Dictionary:
	return {}


func is_reflector() -> bool:
	return false


## a sheet light crosses without bending, leaving only its polarization changed
func is_polarizer() -> bool:
	return false


func contains(_point: Vector2) -> bool:
	return false


## Picking in the editor. A bounding circle is far too coarse here, a thin
## mirror would swallow every click near it
func hit(_point: Vector2, _slack: float) -> bool:
	return false


## The drawn shape, optionally grown. Overlap tests use this so two bodies can
## sit as close as they look rather than as far as their radii
func outline(_inflate: float) -> PackedVector2Array:
	return PackedVector2Array()


## corners the editor turns into handles, empty for anything round
func vertices() -> PackedVector2Array:
	return PackedVector2Array()


## same geometry under a different material, for tracing counterfactual paths
func clone_with(_key: String) -> SceneObj:
	return null


## bounding circle, for overlap rejection while generating
func bounding() -> Dictionary:
	return {"center": Vector2.ZERO, "radius": 0.0}
