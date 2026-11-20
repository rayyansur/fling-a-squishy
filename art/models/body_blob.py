"""Squishy body: blob, with the shared face. Recoloured per species in game (part "Body")."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _squishy import body_model  # noqa: E402

ROBLOX_MATERIALS = {"Body": "SmoothPlastic", "Eyes": "SmoothPlastic", "Shine": "SmoothPlastic", "Blush": "SmoothPlastic", "Mouth": "SmoothPlastic"}


def build(bpy, kit):
    body_model(bpy, kit, "blob")
