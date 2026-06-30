import os
from huggingface_hub import hf_hub_download, login
HF_TOKEN = os.environ.get('HF_TOKEN')
REPO_ID = 'moizpirzada1/oral-vision-models'
files = [
    'best.pt',
    'efficientnet_oral.pth',
    'class_labels_oral.json',
    'OralVision_xgboost.pkl',
    'yolov8m-seg.pt',
    'unet_oral.pth',
]
os.makedirs('models', exist_ok=True)
os.makedirs('models/symptom', exist_ok=True)
if HF_TOKEN:
    login(token=HF_TOKEN)
for f in files:
    dest = f'models/{f}'
    if not os.path.exists(dest):
        print(f'Downloading {f}...')
        hf_hub_download(repo_id=REPO_ID, filename=f, repo_type='model', local_dir='models')
        print(f'Done: {f}')
    else:
        print(f'Already exists: {f}')
print('All models ready!')