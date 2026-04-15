#!/usr/bin/env python3
"""
Logitech G / Saitek Pro Flight Yoke + Throttle + Rudder reader
Requires: pip install pygame
On Linux the bundle exposes 2-3 separate joystick devices; this script
reads all of them simultaneously and prints live control values.
"""

import sys
import pygame

# ── Axis labels per device name (partial-match, case-insensitive) ──────────
# Extend / adjust these if your kernel assigns different names.
AXIS_LABELS: dict[str, list[str]] = {
    "yoke": [
        "Aileron (Roll)",       # axis 0
        "Elevator (Pitch)",     # axis 1
        "Throttle 1",           # axis 2
        "Throttle 2",           # axis 3
        "Prop Pitch / Mixture", # axis 4
        "Toe Brake L",          # axis 5
        "Toe Brake R",          # axis 6
    ],
    "throttle": [
        "Throttle 1",
        "Throttle 2",
        "Prop Pitch",
        "Mixture",
        "Carb Heat / Spare",
    ],
    "rudder": [
        "Rudder",
        "Toe Brake L",
        "Toe Brake R",
    ],
}

BUTTON_LABELS: dict[str, list[str]] = {
    "yoke": [
        "B1 (Trigger)",
        "B2", "B3", "B4",
        "B5 (Hat Switch A Up)",
        "B6 (Hat Switch A Dn)",
        "B7 (Hat Switch A L)",
        "B8 (Hat Switch A R)",
        "B9", "B10", "B11", "B12",
        "B13 (Autopilot Disc)",
        "B14 (TOGA)",
    ],
    "throttle": [
        "B1", "B2", "B3", "B4",
        "B5 (Flap Up)",
        "B6 (Flap Dn)",
        "B7 (Gear Up)",
        "B8 (Gear Dn)",
    ],
    "rudder": [],
}


# ── Helpers ────────────────────────────────────────────────────────────────

def classify(name: str) -> str:
    """Return 'yoke', 'throttle', 'rudder', or 'unknown'."""
    nl = name.lower()
    if "yoke" in nl or "flight yoke" in nl:
        return "yoke"
    if "throttle" in nl or "tq" in nl:
        return "throttle"
    if "rudder" in nl or "pedal" in nl:
        return "rudder"
    return "unknown"


def axis_label(kind: str, idx: int) -> str:
    labels = AXIS_LABELS.get(kind, [])
    return labels[idx] if idx < len(labels) else f"Axis {idx}"


def button_label(kind: str, idx: int) -> str:
    labels = BUTTON_LABELS.get(kind, [])
    return labels[idx] if idx < len(labels) else f"Button {idx}"


def bar(value: float, width: int = 20) -> str:
    """ASCII bar for an axis value in [-1, 1]."""
    filled = int((value + 1) / 2 * width)
    filled = max(0, min(width, filled))
    return "[" + "█" * filled + "░" * (width - filled) + "]"


def fmt_axis(v: float) -> str:
    return f"{v:+.4f}"


# ── Main ───────────────────────────────────────────────────────────────────

def main() -> None:
    pygame.init()
    pygame.joystick.init()

    count = pygame.joystick.get_count()
    if count == 0:
        print("No joystick/HID devices found.")
        print("  • Make sure the bundle is plugged in.")
        print("  • Try:  ls /dev/input/js*")
        print("  • You may need:  pip install pygame")
        sys.exit(1)

    joysticks: list[pygame.joystick.JoystickType] = []
    for i in range(count):
        js = pygame.joystick.Joystick(i)
        js.init()
        joysticks.append(js)
        kind = classify(js.get_name())
        print(
            f"  [{i}] {js.get_name()!r}  →  kind={kind}  "
            f"axes={js.get_numaxes()}  buttons={js.get_numbuttons()}  "
            f"hats={js.get_numhats()}"
        )

    print("\nReading controls — press Ctrl-C to quit.\n")
    print("─" * 72)

    clock = pygame.time.Clock()

    try:
        while True:
            pygame.event.pump()   # pull OS events so values update

            lines: list[str] = []
            for js in joysticks:
                name = js.get_name()
                kind = classify(name)
                lines.append(f"\n▶ {name} ({kind})")

                # Axes
                for a in range(js.get_numaxes()):
                    v = js.get_axis(a)
                    lbl = axis_label(kind, a)
                    lines.append(f"  {lbl:<30} {fmt_axis(v)}  {bar(v)}")

                # Buttons  (only show pressed ones to reduce noise)
                pressed = [
                    button_label(kind, b)
                    for b in range(js.get_numbuttons())
                    if js.get_button(b)
                ]
                if pressed:
                    lines.append(f"  BUTTONS HELD: {', '.join(pressed)}")
                else:
                    lines.append("  BUTTONS HELD: (none)")

                # Hats / POV switches
                for h in range(js.get_numhats()):
                    hv = js.get_hat(h)
                    directions = {
                        ( 0,  0): "Centered",
                        ( 0,  1): "Up",
                        ( 0, -1): "Down",
                        (-1,  0): "Left",
                        ( 1,  0): "Right",
                        ( 1,  1): "Up-Right",
                        (-1,  1): "Up-Left",
                        ( 1, -1): "Down-Right",
                        (-1, -1): "Down-Left",
                    }
                    lines.append(
                        f"  Hat {h}: {hv}  →  {directions.get(hv, str(hv))}"
                    )

            # Overwrite in place
            output = "\n".join(lines)
            num_lines = output.count("\n") + 1
            print(output, end="", flush=True)
            # Move cursor back up
            print(f"\x1b[{num_lines}A", end="", flush=True)

            clock.tick(20)   # 20 Hz refresh

    except KeyboardInterrupt:
        print("\n\nStopped.")
    finally:
        for js in joysticks:
            js.quit()
        pygame.quit()


if __name__ == "__main__":
    main()
