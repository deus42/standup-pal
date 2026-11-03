#!/usr/bin/env python3
"""Pre-render the Ukrainian warm-up phrases with a neural voice.

macOS has only the robotic compact Lesya for Ukrainian, so the built-in exercise names
and warm-up phrases ship as short clips in Resources/Voice/uk. Custom exercises are
still read by the system voice.

Needs Piper (pip install piper-tts==1.8.0) and the uk_UA-ukrainian_tts-medium voice
from https://huggingface.co/rhasspy/piper-voices (CC0). Run it with that Python:

    python -I scripts/render-voice.py <uk_UA-ukrainian_tts-medium.onnx> Resources/Voice/uk

Keys are exercise IDs from Model/Exercise.swift plus the phrases WarmUpSession says.
Stress marks (U+0301 after the vowel) keep the pronunciation right; SpeakerTests checks
that each text still matches the app's Ukrainian name.
"""
import json
import subprocess
import sys
import tempfile
import unicodedata
import wave
from pathlib import Path

from piper import PiperVoice, SynthesisConfig

SPEAKER = "mykyta"
LENGTH_SCALE = 0.85

A = "́"

CLIPS = {
    "reach": f"Тя{A}гнися до не{A}ба",
    "march": f"Ма{A}рш на мі{A}сці",
    "neck": f"Півко{A}ла ши{A}єю",
    "shoulders": f"Ко{A}ла плечи{A}ма",
    "arms": f"Ко{A}ла рука{A}ми",
    "chest": f"Розкри{A}й гру{A}ди",
    "twist": f"Скру{A}чування ко{A}рпусу",
    "sidebend": f"На{A}хили в сто{A}рони",
    "hips": f"Ко{A}ла стегна{A}ми",
    "calves": f"Підйо{A}ми на носки{A}",
    "squats": f"Присіда{A}ння до стільця{A}",
    "hamstrings": f"На{A}хил уни{A}з",
    "wrists": f"Розтя{A}жка зап'я{A}стків",
    "shake": f"Струси{A} напру{A}гу",
    "chintuck": f"Втя{A}гування підборі{A}ддя",
    "blades": f"Зве{A}дення лопа{A}ток",
    "backbend": f"Про{A}гин стоячи{A}",
    "ankles": f"Ко{A}ла стопа{A}ми",
    "deskpushups": f"Віджима{A}ння від сто{A}лу",
    "eyes": f"Пере{A}рва для оче{A}й",
    "breathe": f"Глибо{A}ке ди{A}хання",
    "rest": f"Відпочи{A}нок",
    "getReady": f"Приготу{A}йся",
    "greatJob": f"Чудо{A}ва робо{A}та!",
    "niceWork": f"Молоде{A}ць!",
    "preview": f"Час розім'я{A}тися. Ко{A}ла плечи{A}ма. Чудо{A}ва робо{A}та!",
}


def main():
    model, out = sys.argv[1], Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    voice = PiperVoice.load(model)
    config = SynthesisConfig(speaker_id=voice.config.speaker_id_map[SPEAKER], length_scale=LENGTH_SCALE)
    with tempfile.TemporaryDirectory() as tmp:
        for key, text in CLIPS.items():
            spoken = text if text.endswith(("!", ".")) else text + "."
            wav_path = Path(tmp) / f"{key}.wav"
            with wave.open(str(wav_path), "wb") as wav:
                voice.synthesize_wav(unicodedata.normalize("NFD", spoken.lower()), wav, syn_config=config)
            subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "48000", str(wav_path), str(out / f"{key}.m4a")],
                           check=True)
    manifest = {
        "voice": f"uk_UA-ukrainian_tts-medium/{SPEAKER}",
        "source": "https://huggingface.co/rhasspy/piper-voices/tree/main/uk/uk_UA/ukrainian_tts/medium",
        "license": "CC0 (voice model card)",
        "engine": "piper-tts 1.8.0",
        "lengthScale": LENGTH_SCALE,
        "clips": CLIPS,
    }
    (out / "clips.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(CLIPS)} clips in {out}")


if __name__ == "__main__":
    main()
