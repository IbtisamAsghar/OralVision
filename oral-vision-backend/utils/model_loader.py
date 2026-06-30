import torch
import torch.nn as nn
import json
import torchvision.models as tv_models
from ultralytics import YOLO

MODEL_DIR = "models/"

# ── YOLO Models ───────────────────────────────────────────────
def load_yolo():
    """New 359MB DENTEX YOLO — xray detection"""
    return YOLO(MODEL_DIR + "best.pt")

def load_yolo_seg():
    """Segmentation model"""
    return YOLO(MODEL_DIR + "yolov8m-seg.pt")

# ── EfficientNet-B0 Oral Photos ───────────────────────────────
def load_efficientnet_oral():
    with open(MODEL_DIR + "class_labels_oral.json") as f:
        labels = json.load(f)
    num_classes = len(labels)
    model = tv_models.efficientnet_b0(weights=None)
    in_features = model.classifier[1].in_features  # 1280
    model.classifier = nn.Sequential(
        nn.Dropout(0.4),
        nn.Linear(in_features, 256),
        nn.ReLU(),
        nn.Dropout(0.3),
        nn.Linear(256, num_classes),
    )
    model.load_state_dict(torch.load(
        MODEL_DIR + "efficientnet_oral.pth", map_location="cpu"))
    model.eval()
    return model, labels

# ── U-Net Segmentation ────────────────────────────────────────
class DoubleConv(nn.Module):
    def __init__(self, in_ch, out_ch):
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(in_ch, out_ch, 3, padding=1), nn.ReLU(inplace=True),
            nn.Conv2d(out_ch, out_ch, 3, padding=1), nn.ReLU(inplace=True),
        )
    def forward(self, x): return self.net(x)

class UNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.c1 = DoubleConv(3, 32);  self.c2 = DoubleConv(32, 64)
        self.c3 = DoubleConv(64, 128); self.bottleneck = DoubleConv(128, 256)
        self.pool = nn.MaxPool2d(2)
        self.up1 = nn.ConvTranspose2d(256, 128, 2, stride=2); self.c4 = DoubleConv(256, 128)
        self.up2 = nn.ConvTranspose2d(128, 64,  2, stride=2); self.c5 = DoubleConv(128, 64)
        self.up3 = nn.ConvTranspose2d(64,  32,  2, stride=2); self.c6 = DoubleConv(64, 32)
        self.out = nn.Conv2d(32, 1, 1)
    def forward(self, x):
        c1=self.c1(x); c2=self.c2(self.pool(c1)); c3=self.c3(self.pool(c2))
        b=self.bottleneck(self.pool(c3))
        u1=self.c4(torch.cat([self.up1(b),  c3], 1))
        u2=self.c5(torch.cat([self.up2(u1), c2], 1))
        u3=self.c6(torch.cat([self.up3(u2), c1], 1))
        return torch.sigmoid(self.out(u3))

def load_unet():
    model = UNet()
    model.load_state_dict(torch.load(
        MODEL_DIR + "unet_oral.pth", map_location="cpu"))
    model.eval()
    return model