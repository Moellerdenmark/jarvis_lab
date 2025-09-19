from TTS.api import TTS
tts = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=False, gpu=False)
tts.tts_to_file(text="Hej Kenneth, jeg er Jarvis, og nu taler jeg dansk.", file_path=r"C:\Users\gubbi\jarvis_core\out.wav", speaker_wav=None, language="da")
