from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout,
                             QHBoxLayout, QPushButton, QLabel, QComboBox, QSpinBox)
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QPainter, QColor, QMouseEvent
import sys
from main import *

cize_c = 4


class WorldView(QWidget):
    def __init__(self):
        super().__init__()
        self.setFixedSize(world_w * cize_c, world_h * cize_c)
        self.s_material = "stone"
        self.drawing = False
        self.ster = False
        self.brush_size = 10
        self.paused = False

        self.create_borders()

        self.t = QTimer()
        self.t.timeout.connect(self.update_simulation)
        self.t.start(50)

    def create_borders(self):
        for x in range(world_w):
            world[(x, 0)] = Solid(x, 0, White)
            world[(x, world_h - 1)] = Solid(x, world_h - 1, White)

        for y in range(world_h):
            world[(0, y)] = Solid(0, y, White)
            world[(world_w - 1, y)] = Solid(world_w - 1, y, White)

    def update_simulation(self):
        if not self.paused:
            materials = list(world.values())
            random.shuffle(materials)

            for material in materials:
                material.action()

        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setPen(Qt.PenStyle.NoPen)

        painter.fillRect(0, 0, self.width(), self.height(), QColor(*empty))

        for (x, y), material in world.items():
            if 0 <= x < world_w and 0 <= y < world_h:
                color = material.fake_color
                painter.setBrush(QColor(*color))
                painter.drawRect(x * cize_c, y * cize_c, cize_c, cize_c)

    def mousePressEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.LeftButton:
            self.drawing = True
        elif event.button() == Qt.MouseButton.RightButton:
            self.ster = True
        self.handle_mouse(event)

    def mouseMoveEvent(self, event: QMouseEvent):
        self.handle_mouse(event)

    def mouseReleaseEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.LeftButton:
            self.drawing = False
        elif event.button() == Qt.MouseButton.RightButton:
            self.ster = False

    def handle_mouse(self, event: QMouseEvent):
        pos = event.pos()
        x = pos.x() // cize_c
        y = pos.y() // cize_c

        if self.drawing or self.ster:
            self.draw_circle(x, y, self.brush_size, self.drawing)

    def draw_circle(self, center_x, center_y, radius, drawing=True):
        for dx in range(-radius, radius + 1):
            for dy in range(-radius, radius + 1):
                if dx * dx + dy * dy <= radius * radius:
                    x = center_x + dx
                    y = center_y + dy

                    if 1 <= x < world_w - 1 and 1 <= y < world_h - 1:
                        if drawing:
                            self.add_material(x, y)
                        else:
                            self.remove_material(x, y)

    def add_material(self, x, y):
        remove_substance(x, y)

        if self.s_material == "sand":
            add_substance(Sand(x, y))
        elif self.s_material == "water":
            add_substance(Water(x, y))
        elif self.s_material == "stone":
            add_substance(Stone(x, y))
        elif self.s_material == "smoke":
            add_substance(Smoke(x, y))
        elif self.s_material == "fire":
            add_substance(Fire(x, y))
        elif self.s_material == "wood":
            add_substance(Wood(x, y))
        elif self.s_material == "solid":
            add_substance(Solid(x, y, White))
        elif self.s_material == "plasm":
            add_substance(Plasm(x, y))
        elif self.s_material == "steam":
            add_substance(Steam(x, y))
        elif self.s_material == "lava":
            add_substance(Lava(x, y, stone))
        elif self.s_material == "powder":
            add_substance(Powder(x, y))
        elif self.s_material == "snow":
            add_substance(Snow(x, y))
        elif self.s_material == "petrol":
            add_substance(Petrol(x, y))
        elif self.s_material == "acid":
            add_substance(Acid(x, y))
        elif self.s_material == "iron":
            add_substance(Iron(x, y))

    def remove_material(self, x, y):
        remove_substance(x, y)

    def set_material(self, material):
        self.s_material = material

    def set_brush_size(self, size):
        self.brush_size = size

    def toggle_pause(self):
        self.paused = not self.paused

    def clear_world(self):

        borders = {}
        for (x, y), material in world.items():
            if (x == 0 or x == world_w - 1 or y == 0 or y == world_h - 1):
                borders[(x, y)] = material

        world.clear()
        world.update(borders)
        self.update()


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Физическая песочница")

        central_widget = QWidget()
        self.setCentralWidget(central_widget)

        main_layout = QVBoxLayout()
        controls_layout = QHBoxLayout()
        brush_layout = QHBoxLayout()

        self.world_view = WorldView()

        self.material_combo = QComboBox()
        self.material_combo.addItems([
            "stone", "wood", "iron", "solid", "sand", "powder", "snow", "water",
            "petrol", "acid", "lava", "steam", "fire", "plasm"
        ])
        self.material_combo.currentTextChanged.connect(self.world_view.set_material)

        brush_layout.addWidget(QLabel("Размер кисти:"))
        self.brush_spin = QSpinBox()
        self.brush_spin.setRange(1, 10)
        self.brush_spin.setValue(10)
        self.brush_spin.valueChanged.connect(self.world_view.set_brush_size)
        brush_layout.addWidget(self.brush_spin)
        brush_layout.addStretch()

        clear_button = QPushButton("Очистить")
        clear_button.clicked.connect(self.world_view.clear_world)

        pause_button = QPushButton("Пауза")
        pause_button.clicked.connect(self.world_view.toggle_pause)

        controls_layout.addWidget(QLabel("Материал:"))
        controls_layout.addWidget(self.material_combo)
        controls_layout.addWidget(clear_button)
        controls_layout.addWidget(pause_button)
        controls_layout.addStretch()

        main_layout.addLayout(controls_layout)
        main_layout.addLayout(brush_layout)
        main_layout.addWidget(self.world_view)

        central_widget.setLayout(main_layout)


if __name__ == "__main__":
    app = QApplication(sys.argv)

    window = MainWindow()
    window.show()

    sys.exit(app.exec())