LingChat 19-emotion ONNX runtime payload

The binary model is intentionally not committed to this Git repository.
GitHub Actions downloads the pinned ModelScope files during the APK build:

model_int8_o2/model.onnx
SHA-256: 677b784abed285d22532df725b8e1947957a1d254b0c899a37a4a93a2a5b473e
Bytes: 60004728

model_int8_o2/vocab.txt
SHA-256: 45bbac6b341c319adc98a532532882e91a9cefc0329aa57bac9ae761c27b291c

model_int8_o2/label_mapping.json
SHA-256: 925c356c9a692e8d6a0466cc8d1bc0d40c40cf0ccc5b59695916d925319d4a78

Source:
https://www.modelscope.cn/models/lingchat-research-studio/Emotion_model_19emo_small_onnx

The model only normalizes one reply into one of 19 expression labels. It does
not replace the persistent Desire/Thought/Mood state and does not itself make
Meju TTS emotionally conditioned.
