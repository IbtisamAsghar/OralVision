import torch
import torch.nn as nn

class SEBlock(nn.Module):
    def __init__(self, channels, reduction=16):
        super().__init__()
        self.se = nn.Sequential(
            nn.AdaptiveAvgPool2d(1),
            nn.Flatten(),
            nn.Linear(channels, channels // reduction, bias=False),
            nn.ReLU(),
            nn.Linear(channels // reduction, channels, bias=False),
            nn.Sigmoid()
        )
    def forward(self, x):
        return x * self.se(x).view(x.size(0), -1, 1, 1)

class StridedConvBlock(nn.Module):
    def __init__(self, in_ch, out_ch):
        super().__init__()
        self.conv = nn.Sequential(
            nn.Conv2d(in_ch, out_ch, 3, stride=2, padding=1, bias=False),
            nn.BatchNorm2d(out_ch), nn.ReLU6(),
            nn.Conv2d(out_ch, out_ch, 3, padding=1, bias=False),
            nn.BatchNorm2d(out_ch), nn.ReLU6()
        )
        self.se = SEBlock(out_ch, reduction=16)
    def forward(self, x):
        return self.se(self.conv(x))

class AttentionBlock(nn.Module):
    def __init__(self, dim, num_heads):
        super().__init__()
        self.attention = nn.MultiheadAttention(dim, num_heads, batch_first=True)
        self.norm1 = nn.LayerNorm(dim)
        self.norm2 = nn.LayerNorm(dim)
        self.ffn = nn.Sequential(
            nn.Linear(dim, dim * 2), nn.GELU(), nn.Dropout(0.1),
            nn.Linear(dim * 2, dim)
        )
    def forward(self, x):
        attn_out, _ = self.attention(x, x, x)
        x = self.norm1(x + attn_out)
        return self.norm2(x + self.ffn(x))

class InvertedResidual(nn.Module):
    def __init__(self, in_ch, out_ch, stride=1, expand_ratio=6):
        super().__init__()
        hidden = in_ch * expand_ratio
        self.use_res = (stride == 1 and in_ch == out_ch)
        if expand_ratio == 1:
            self.conv = nn.Sequential(
                nn.Sequential(nn.Conv2d(hidden, hidden, 3, stride=stride, padding=1, groups=hidden, bias=False),
                              nn.BatchNorm2d(hidden), nn.ReLU6()),
                nn.Conv2d(hidden, out_ch, 1, bias=False),
                nn.BatchNorm2d(out_ch)
            )
        else:
            self.conv = nn.Sequential(
                nn.Sequential(nn.Conv2d(in_ch, hidden, 1, bias=False),
                              nn.BatchNorm2d(hidden), nn.ReLU6()),
                nn.Sequential(nn.Conv2d(hidden, hidden, 3, stride=stride, padding=1, groups=hidden, bias=False),
                              nn.BatchNorm2d(hidden), nn.ReLU6()),
                nn.Conv2d(hidden, out_ch, 1, bias=False),
                nn.BatchNorm2d(out_ch)
            )
    def forward(self, x):
        return x + self.conv(x) if self.use_res else self.conv(x)

class OralVisionModel(nn.Module):
    def __init__(self, num_classes=7, num_heads=8, attn_dim=512):
        super().__init__()
        self.backbone = nn.Sequential(
            nn.Sequential(nn.Conv2d(3, 32, 3, stride=2, padding=1, bias=False), nn.BatchNorm2d(32), nn.ReLU6()),
            InvertedResidual(32, 16, stride=1, expand_ratio=1),
            InvertedResidual(16, 24, stride=2, expand_ratio=6),
            InvertedResidual(24, 24, stride=1, expand_ratio=6),
            InvertedResidual(24, 32, stride=2, expand_ratio=6),
            InvertedResidual(32, 32, stride=1, expand_ratio=6),
            InvertedResidual(32, 32, stride=1, expand_ratio=6),
            InvertedResidual(32, 64, stride=2, expand_ratio=6),
            InvertedResidual(64, 64, stride=1, expand_ratio=6),
            InvertedResidual(64, 64, stride=1, expand_ratio=6),
            InvertedResidual(64, 64, stride=1, expand_ratio=6),
            InvertedResidual(64, 96, stride=1, expand_ratio=6),
            InvertedResidual(96, 96, stride=1, expand_ratio=6),
            InvertedResidual(96, 96, stride=1, expand_ratio=6),
            InvertedResidual(96, 160, stride=2, expand_ratio=6),
            InvertedResidual(160, 160, stride=1, expand_ratio=6),
            InvertedResidual(160, 160, stride=1, expand_ratio=6),
            InvertedResidual(160, 320, stride=1, expand_ratio=6),
            nn.Sequential(nn.Conv2d(320, 1280, 1, bias=False), nn.BatchNorm2d(1280), nn.ReLU6()),
        )
        self.se_block = SEBlock(1280, reduction=16)
        self.strided_conv = StridedConvBlock(1280, attn_dim)
        self.pos_enc = nn.Parameter(torch.zeros(1, 16, attn_dim))
        self.attention = AttentionBlock(attn_dim, num_heads)

    def forward(self, x):
        x = self.backbone(x)
        x = self.se_block(x)
        x = self.strided_conv(x)
        B, C, H, W = x.shape
        x = x.flatten(2).transpose(1, 2)
        x = x + self.pos_enc[:, :x.size(1), :]
        x = self.attention(x)
        return x.mean(dim=1)
