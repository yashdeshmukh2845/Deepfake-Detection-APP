import torch
import torch.nn as nn
from torchvision import models

class DeepfakeDetector(nn.Module):
    def __init__(self):
        super(DeepfakeDetector, self).__init__()
        # Load EfficientNet-B0 without predefined weights
        self.model = models.efficientnet_b0(pretrained=False)
        
        # Replace the classifier matching the training architecture
        # in_features of efficientnet_b0 is 1280
        in_features = self.model.classifier[1].in_features
        self.model.classifier = nn.Sequential(
            nn.Dropout(p=0.4, inplace=True),
            nn.Linear(in_features, 2)
        )

    def forward(self, x):
        return self.model(x)
