"""World model frosted_peak (see _world.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _world  # noqa: E402

ROBLOX_MATERIALS = {}


def build(bpy, kit):
    _world.frosted_peak(bpy, kit)
