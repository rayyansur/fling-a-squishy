"""World model lollipop_tree (see _world.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _world  # noqa: E402

ROBLOX_MATERIALS = {}


def build(bpy, kit):
    _world.lollipop_tree(bpy, kit)
