"""Shelf level 1 (DESIGN 2.1): three curved candy tiers ~22 studs wide. Pins centre the bounding
box on the shelf anchor; the map hides them. Tier heights/depths match ShelfView."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _world  # noqa: E402

ROBLOX_MATERIALS = {}


def build(bpy, kit):
    _world.shelf(bpy, kit, 1)
