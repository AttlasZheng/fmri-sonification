import time
import csv
import os
from pythonosc import udp_client
from PyQt5.QtCore import QThread, pyqtSignal
import numpy as np
import pygame

class SequencerThread(QThread):
    status = pyqtSignal(str)

    def __init__(self, filepath):
        super().__init__()
        self.filepath = filepath
        self.is_paused = False
        self.is_stopped = False
        self.ip = "127.0.0.1"
        self.port = 1337
        self.row = 0
        self.client = None
        self.axis_scale = 5.0
        self.axis_deadzone = 0.10
        self.joystick = None

    def run(self):
        self.client = udp_client.SimpleUDPClient(self.ip, self.port)
        os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
        pygame.display.init()
        pygame.display.set_mode((1, 1))
        pygame.joystick.init()
        joysticks = [pygame.joystick.Joystick(x) for x in range(pygame.joystick.get_count())]

        joysticks = []
        for x in range(pygame.joystick.get_count()):
            js = pygame.joystick.Joystick(x)
            js.init()
            joysticks.append(js)

        try:
            if pygame.joystick.get_count() == 0:
                self.status.emit("Error: no joystick found")
                return

            column_ranges = self.get_column_ranges()
            if not column_ranges:
                self.status.emit("Error: no numeric data found in file")
                return

            normalized_rows = []
            with open(self.filepath, newline="") as f:
                for row in csv.reader(f):
                    normalized_row = []
                    for idx, cell in enumerate(row):
                        try:
                            value = float(cell)
                        except ValueError:
                            continue

                        data_min, data_max = column_ranges.get(idx, (None, None))
                        if data_min is None or data_max is None:
                            continue

                        normalized_row.append(self.normalize_minmax(value, data_min, data_max))

                    if normalized_row:
                        normalized_rows.append(normalized_row)

            if not normalized_rows:
                self.status.emit("Error: no numeric rows found in file")
                return

            prevRow = None
            while not self.is_stopped:
                while self.is_paused and not self.is_stopped:
                    time.sleep(0.05)

                if self.is_stopped:
                    self.status.emit("Stopped")
                    return

                index = int(np.clip(self.row, 0, len(normalized_rows) - 1))
                if index != prevRow:
                    self.client.send_message("/row", normalized_rows[index])
                    prevRow = index
                    self.status.emit(
                        f"Sent row: {index}, IP: {self.ip}, Port: {self.port}"
                    )

                pygame.event.pump()
                axis_value = joysticks[0].get_axis(1) # elevator joystick
                if abs(axis_value) < self.axis_deadzone:
                    axis_value = 0.0
                self.row += (axis_value ** 3) * self.axis_scale

                time.sleep(0.05)

        except Exception as e:
            self.status.emit(f"Error: {e}")
        finally:
            if self.joystick is not None:
                self.joystick.quit()
            pygame.joystick.quit()
            pygame.display.quit()

    def pause(self):
        self.is_paused = True
        self.status.emit("Paused")

    def resume(self):
        self.is_paused = False
        self.status.emit("Playing")

    def stop(self):
        self.is_stopped = True
        self.is_paused = False

    def set_port(self, port):
        self.port = port
        self.client = udp_client.SimpleUDPClient(self.ip, self.port)

    def set_ip(self, ip):
        self.ip = ip
        self.client = udp_client.SimpleUDPClient(self.ip, self.port)

    def set_row(self, row):
        self.row = row

    def get_column_ranges(self):
        column_values = {}
        with open(self.filepath, newline="") as f:
            for row in csv.reader(f):
                for idx, cell in enumerate(row):
                    try:
                        value = float(cell)
                    except ValueError:
                        continue
                    column_values.setdefault(idx, []).append(value)

        ranges = {}
        for idx, values in column_values.items():
            if values:
                ranges[idx] = (min(values), max(values))
        return ranges

    def normalize_minmax(self, value, data_min, data_max):
        if data_max == data_min:
            return 0
        return (value - data_min) / (data_max - data_min)
