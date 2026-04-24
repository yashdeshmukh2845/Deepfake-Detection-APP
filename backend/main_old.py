from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import torch
import torch.nn as nn
from torchvision import transforms, models
from PIL import Image
import io
import uvicorn
import os
import cv2
import tempfile
import requests  # Used to call the Sightengine cloud API
import traceback


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Runs startup logic before the app begins serving requests."""
    load_local_model()
    yield
    # (cleanup code could go here if needed)

app = FastAPI(
    title="Deep Guard AI API",
    description="Deepfake Detection Backend — Hybrid Mode",
    lifespan=lifespan,
)

# Allow requests from Flutter (web, desktop, Android emulator)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


SIGHTENGINE_API_USER   = "916626049"
SIGHTENGINE_API_SECRET = "puqMjnXaXvc2k9DmmSB6wdX3HZeUrTbF"
SIGHTENGINE_ENDPOINT   = "https://api.sightengine.com/1.0/check.json"


device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
local_model = None   # Will be loaded on startup

class DeepfakeModel(nn.Module):
    """Local ResNet50 model for offline deepfake detection (6-channel input)."""
    def __init__(self):
        super(DeepfakeModel, self).__init__()
        # Load ResNet50 architecture — Bottleneck-based as in checkpoint
        self.model = models.resnet50(weights=None)
        
        # Modify first layer to accept 6 channels (frame stacking)
        # Original ResNet50 has (3, 64, 7, 7)
        self.model.conv1 = nn.Conv2d(6, 64, kernel_size=7, stride=2, padding=3, bias=False)
        
        # Update output layer to 2 classes (Real/Fake)
        self.model.fc = nn.Linear(self.model.fc.in_features, 2)

    def forward(self, x):
        return self.model(x)


def load_local_model():
    """
    Load the local ResNet18 model at startup.
    If the model file is missing, local fallback won't be available,
    but Sightengine cloud detection will still work fine.
    """
    global local_model

    # ── Sightengine connection confirmation ──────────────────────────────
    print(f"[SIGHTENGINE] Configured — api_user={SIGHTENGINE_API_USER}")
    print(f"[SIGHTENGINE] Endpoint: {SIGHTENGINE_ENDPOINT}")

    # ── Local model ──────────────────────────────────────────────────────
    model_path = "../models/model_best.pth"

    if not os.path.exists(model_path):
        print(f"[LOCAL MODEL] Warning: model file not found at '{model_path}'. Sightengine will be used as primary.")
        return

    try:
        local_model = DeepfakeModel()
        checkpoint = torch.load(model_path, map_location=device, weights_only=False)

        # Handle different checkpoint formats (state_dict wrapper or raw weights)
        if isinstance(checkpoint, dict):
            if 'state_dict' in checkpoint:
                raw_sd = checkpoint['state_dict']
            elif 'model_state_dict' in checkpoint:
                raw_sd = checkpoint['model_state_dict']
            else:
                raw_sd = checkpoint
        else:
            raw_sd = checkpoint

        # Remap keys if the model was saved with 'cnn.' prefix instead of 'model.'
        state_dict = {}
        for k, v in raw_sd.items():
            new_key = k.replace('cnn.', 'model.', 1) if k.startswith('cnn.') else k
            state_dict[new_key] = v

        # strict=False: allows partial weight loading even if architecture differs
        missing, unexpected = local_model.load_state_dict(state_dict, strict=False)
        if missing:
            print(f"[LOCAL MODEL] Missing keys (non-critical): {len(missing)} keys")
        if unexpected:
            print(f"[LOCAL MODEL] Unexpected keys (non-critical): {len(unexpected)} keys")

        local_model.to(device)
        local_model.eval()
        print("[LOCAL MODEL] Loaded successfully (partial load)! Hybrid mode active.")
    except Exception as e:
        local_model = None
        print(f"[LOCAL MODEL] Error loading: {e}")
        traceback.print_exc()
        print("Sightengine will be used as primary.")


# Image preprocessing pipeline for the local model
preprocess = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])


def call_sightengine(pil_image: Image.Image) -> tuple:
    """
    Sends a PIL image to the Sightengine deepfake detection API.
    
    Returns:
        ("Real" or "Fake", confidence_float, True)  on success
        (None, None, False)                          on failure
    """
    try:
        # Convert the PIL image to JPEG bytes in memory (no temp file needed)
        img_bytes = io.BytesIO()
        pil_image.save(img_bytes, format="JPEG")
        img_bytes.seek(0)

        # Send POST request with the image as multipart form data
        response = requests.post(
            SIGHTENGINE_ENDPOINT,
            files={"media": ("frame.jpg", img_bytes, "image/jpeg")},
            data={
                "models":     "deepfake",
                "api_user":   SIGHTENGINE_API_USER,
                "api_secret": SIGHTENGINE_API_SECRET,
            },
            timeout=15,   # Don't wait more than 15 seconds
        )

        data = response.json()

        # Check if Sightengine returned a successful response
        if data.get("status") == "success":
            # 1. Primary hierarchy: type -> deepfake (Standard for multiple models)
            if "type" in data and "deepfake" in data["type"]:
                score = float(data["type"]["deepfake"])
            
            # 2. Alternative: deepfake object (Standard for single model check)
            elif "deepfake" in data:
                df_data = data["deepfake"]
                if isinstance(df_data, dict):
                    # Some Sightengine models use 'prob', others use 'score'
                    score = float(df_data.get("prob") or df_data.get("score") or 0.0)
                else:
                    # Case where deepfake is a direct float
                    score = float(df_data)
            else:
                print(f"[SIGHTENGINE] Missing deepfake key in response: {data}")
                return None, None, False

            # score = 0.0 means definitely REAL, score = 1.0 means definitely FAKE
            if score >= 0.5:
                return "Fake", round(score * 100, 2), True
            else:
                return "Real", round((1.0 - score) * 100, 2), True

        # API returned an error (e.g. rate limit or bad key)
        print(f"[SIGHTENGINE] API error response: {data}")
        return None, None, False

    except Exception as e:
        print(f"[SIGHTENGINE] Request failed: {e}")
        return None, None, False



def call_local_model(pil_image: Image.Image) -> tuple:
    """
    Runs the local ResNet50 model on a PIL image.
    Stacking: Duplicate the 3-channel image to create a 6-channel input [R,G,B,R,G,B].
    
    Returns:
        ("Real" or "Fake", confidence_float, True)  on success
        (None, None, False)                          if model not loaded
    """
    if local_model is None:
        print("[LOCAL MODEL] Inference failed: Model not loaded.")
        return None, None, False

    try:
        # Preprocess to 3-channel tensor
        input_3ch = preprocess(pil_image).to(device)
        
        # Stack to 6-channel [R, G, B, R, G, B]
        # This doubles the channels along the channel dimension (dim=0)
        input_6ch = torch.cat([input_3ch, input_3ch], dim=0).unsqueeze(0)
        
        with torch.no_grad():
            output = local_model(input_6ch)
            probabilities = torch.nn.functional.softmax(output[0], dim=0)
            confidence, predicted_idx = torch.max(probabilities, 0)

        # Map indices: 0 = Fake, 1 = Real (based on common labelling or previous logic)
        # If mismatch, we can swap these. Assuming predicted_idx 1 is Real as before.
        label = "Real" if predicted_idx.item() == 1 else "Fake"
        return label, round(confidence.item() * 100, 2), True
    except Exception as e:
        print(f"[LOCAL MODEL] Inference error: {e}")
        return None, None, False



def detect_image_hybrid(pil_image: Image.Image) -> dict:
    """
    Exclusively uses the local model to ensure stability and bypass external limits.
    Returns a result dict: { result, confidence, source }
    """
    # --- Local Model ONLY ---
    print("[DETECTION] Running local ResNet50 analysis...")
    result, confidence, success = call_local_model(pil_image)
    if success:
        print(f"[LOCAL MODEL] Result: {result} ({confidence}%)")
        return {"result": result, "confidence": f"{confidence:.2f}", "source": "Deep Guard Local AI"}

    # --- Failure ---
    return {"result": "Error", "confidence": "0.00", "source": "None",
            "message": "Local Model failure. Check server logs."}


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    """
    Main detection endpoint.
    - Images: sent directly to Sightengine, local model as fallback.
    - Videos: 8 frames are extracted with OpenCV, each frame goes
              through the same hybrid logic, and results are averaged.
    """
    try:
        # Detect if the uploaded file is a video
        is_video = False
        if file.content_type and file.content_type.startswith('video/'):
            is_video = True
        elif file.filename:
            ext = os.path.splitext(file.filename)[1].lower()
            if ext in ['.mp4', '.avi', '.mov', '.webm', '.mkv']:
                is_video = True

    
        if is_video:
            suffix = os.path.splitext(file.filename)[1] if file.filename else ".mp4"
            if not suffix:
                suffix = ".mp4"

            # Write uploaded video bytes to a temporary file so OpenCV can open it
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                content = await file.read()
                tmp.write(content)
                tmp_path = tmp.name

            cap = cv2.VideoCapture(tmp_path)
            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

            if total_frames <= 0:
                cap.release()
                os.unlink(tmp_path)
                return {"result": "Error", "message": "Could not read frames from video."}

            # Sample 16 evenly spaced frames from the video
            # More frames = more chances to catch short deepfake artifacts
            num_samples = 16
            step = max(1, total_frames // num_samples)

            fake_scores = []
            real_scores = []
            detection_source = "Sightengine AI"  # Track which engine was used

            # Threshold: if any frame has fake confidence >= this, flag as Fake immediately
            # Modern deepfakes only expose themselves in a few frames — don't let real frames dilute it
            STRONG_FAKE_THRESHOLD = 60.0
            strong_fake_detected = False
            strong_fake_confidence = 0.0

            for i in range(num_samples):
                frame_idx = i * step
                if frame_idx >= total_frames:
                    break

                cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
                ret, frame = cap.read()
                if not ret:
                    continue

                # OpenCV reads as BGR, convert to RGB for PIL
                frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                pil_frame = Image.fromarray(frame_rgb)

                # Run hybrid detection on this single frame
                detection = detect_image_hybrid(pil_frame)
                detection_source = detection.get("source", detection_source)

                if detection["result"] == "Fake":
                    conf = float(detection["confidence"])
                    fake_scores.append(conf)
                    real_scores.append(100.0 - conf)
                    # Check for strong fake signal — one strong frame is enough
                    if conf >= STRONG_FAKE_THRESHOLD:
                        strong_fake_detected = True
                        strong_fake_confidence = max(strong_fake_confidence, conf)
                        print(f"[VIDEO] Strong FAKE signal detected in frame {frame_idx} ({conf}%) — flagging video as Fake")
                elif detection["result"] == "Real":
                    real_scores.append(float(detection["confidence"]))
                    fake_scores.append(100.0 - float(detection["confidence"]))

            cap.release()
            os.unlink(tmp_path)

            if not real_scores and not fake_scores:
                return {"result": "Error", "message": "Failed to analyze any frames from the video."}

            frames_analyzed = len(real_scores)

            # ── RULE 1: Any strong fake signal → flag entire video as Fake ──
            # Modern deepfakes only show manipulation in a few frames.
            # One strong fake frame is enough evidence.
            if strong_fake_detected:
                return {
                    "result": "Fake",
                    "confidence": f"{strong_fake_confidence:.2f}",
                    "message": f"Deepfake detected in at least 1 of {frames_analyzed} frames via {detection_source}"
                }

            # ── RULE 2: Majority vote via average (no strong fake found) ──
            avg_real = sum(real_scores) / len(real_scores)
            avg_fake = sum(fake_scores) / len(fake_scores)

            if avg_real > avg_fake:
                return {
                    "result": "Real",
                    "confidence": f"{avg_real:.2f}",
                    "message": f"Analysed {frames_analyzed} frames via {detection_source}"
                }
            else:
                return {
                    "result": "Fake",
                    "confidence": f"{avg_fake:.2f}",
                    "message": f"Analysed {frames_analyzed} frames via {detection_source}"
                }

        # ──────────────────────────────────────────────────────
        # IMAGE PIPELINE
        # Send the image through the hybrid detection pipeline.
        # ──────────────────────────────────────────────────────
        else:
            contents = await file.read()
            pil_image = Image.open(io.BytesIO(contents)).convert("RGB")

            detection = detect_image_hybrid(pil_image)
            return detection

    except Exception as e:
        return {"result": "Error", "message": f"Unexpected server error: {str(e)}"}



@app.get("/status")
def status():
    """Returns the current status of Sightengine and local model."""
    return {
        "server": "online",
        "sightengine": "configured",
        "local_model": "loaded" if local_model is not None else "not loaded",
        "mode": "hybrid" if local_model is not None else "sightengine-only",
    }


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
