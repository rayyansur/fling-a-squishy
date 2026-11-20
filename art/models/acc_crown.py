"""Squishy accessory acc_crown (built on its species' body; see _accs.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _accs import build_acc  # noqa: E402

ROBLOX_MATERIALS = {}


def build(bpy, kit):
    build_acc(bpy, kit, "acc_crown")
