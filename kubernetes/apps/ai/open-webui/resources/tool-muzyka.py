"""
title: Muzyka
description: Generuje muzykę i efekty dźwiękowe na ragnaroku (ComfyUI, RX 9070 XT): podkłady, piosenki z tekstem w wielu językach (w tym po polsku) i krótkie dźwięki do gier.
version: 1.1.0
"""

# Open WebUI tool (Workspace -> Tools). Source of truth: home-ops
# kubernetes/apps/ai/open-webui/resources/tool-muzyka.py. ComfyUI runs on ragnarok
# (nix-config modules/services/comfyui.nix); /ragnarok/progress is its local glue node.

import asyncio
import base64
import html
import random
import uuid

import aiohttp
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field


def ace_step(style, lyrics, seconds, language, bpm, key, seed):
    """ACE-Step 1.5 turbo: ~20 s per minute of audio, instrumentals and songs."""
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "acestep_v1.5_turbo.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "DualCLIPLoader", "inputs": {"clip_name1": "qwen_0.6b_ace15.safetensors", "clip_name2": "qwen_1.7b_ace15.safetensors", "type": "ace", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "ace_1.5_vae.safetensors"}},
        "4": {"class_type": "TextEncodeAceStepAudio1.5", "inputs": {"clip": ["2", 0], "tags": style, "lyrics": lyrics, "seed": seed, "bpm": bpm, "duration": seconds, "timesignature": "4", "language": language, "keyscale": key, "generate_audio_codes": True, "cfg_scale": 2, "temperature": 0.85, "top_p": 0.9, "top_k": 0, "min_p": 0}},
        "5": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["4", 0]}},
        "6": {"class_type": "EmptyAceStep1.5LatentAudio", "inputs": {"seconds": seconds, "batch_size": 1}},
        "7": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["1", 0], "shift": 3}},
        "8": {"class_type": "KSampler", "inputs": {"model": ["7", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["6", 0], "seed": seed, "steps": 8, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
        "9": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveAudioOpus", "inputs": {"audio": ["9", 0], "filename_prefix": "openwebui/muzyka", "quality": "128k"}},
    }


def minimax_music3(style, lyrics, seconds, seed):
    """MiniMax Music 3: best vocals and arrangement, ~4-5 min per song."""
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "minimax_music3_dit_fp16.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "minimax_music3_text_encoder_pruned_int8_convrot.safetensors", "type": "minimax", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_music3_dav.safetensors"}},
        "4": {"class_type": "MiniMaxMusic3TextEncode", "inputs": {"clip": ["2", 0], "caption": style, "lyrics": lyrics, "seed": seed, "max_duration": seconds, "cfg_scale": 1.7, "top_k": 50}},
        "5": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["4", 0]}},
        "6": {"class_type": "EmptyMiniMaxMusic3LatentAudio", "inputs": {"seconds": ["4", 1], "batch_size": 1}},
        "7": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["6", 0], "seed": seed, "steps": 30, "cfg": 1.7, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
        "8": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["7", 0], "vae": ["3", 0]}},
        "9": {"class_type": "SaveAudioOpus", "inputs": {"audio": ["8", 0], "filename_prefix": "openwebui/piosenka", "quality": "128k"}},
    }


def stable_audio3(description, seconds, seed):
    """Stable Audio 3 Medium (8-step LCM): sound effects and ambiences, ~2 s.
    The Small SFX checkpoint only produces noise on this ComfyUI/ROCm stack."""
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "stable_audio_3_medium.safetensors"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "t5gemma_b_b_ul2.safetensors", "type": "stable_audio", "device": "default"}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": description}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": ""}},
        "5": {"class_type": "EmptyLatentAudio", "inputs": {"seconds": seconds, "batch_size": 1}},
        "6": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "positive": ["3", 0], "negative": ["4", 0], "latent_image": ["5", 0], "seed": seed, "steps": 8, "cfg": 1, "sampler_name": "lcm", "scheduler": "simple", "denoise": 1}},
        "7": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveAudioOpus", "inputs": {"audio": ["7", 0], "filename_prefix": "openwebui/efekt", "quality": "128k"}},
    }


class Tools:
    class Valves(BaseModel):
        comfyui_url: str = Field(default="http://10.100.0.102:8188", description="ComfyUI on ragnarok")
        timeout_seconds: int = Field(default=900, description="Give up after this long")

    def __init__(self):
        self.valves = self.Valves()

    async def generate_music(
        self,
        style: str,
        lyrics: str = "[Instrumental]",
        seconds: int = 30,
        language: str = "en",
        bpm: int = 100,
        key: str = "C major",
        best_vocals: bool = False,
        __event_emitter__=None,
    ):
        """
        Generate a piece of music or a song and play it in the chat. Use it whenever the user asks for music, a song, a jingle, a soundtrack or background music.
        :param style: Musical description in English: genre, mood, tempo, instruments, voice (e.g. "cozy lo-fi acoustic guitar, warm piano, relaxing, instrumental" or "funny Polish polka-pop, accordion, cheerful male vocal").
        :param lyrics: Song lyrics in the song's language, with section tags like [Verse], [Chorus], [Bridge]. Use "[Instrumental]" for music without vocals.
        :param seconds: Length in seconds, 10 to 120.
        :param language: ISO 639-1 code of the lyrics language, e.g. "pl" or "en".
        :param bpm: Tempo in beats per minute, 10 to 300 (e.g. 70 calm, 100 medium, 128 dance). Ignored when best_vocals is True.
        :param key: Musical key like "C major" or "A minor". Ignored when best_vocals is True.
        :param best_vocals: True for the slower model with the best vocals (MiniMax Music 3, about 5 minutes); False for the fast one (ACE-Step, about 20 seconds). Only use True when the user asks for the best quality.
        """

        seconds = max(10, min(120, int(seconds)))
        seed = random.randint(0, 2**31 - 1)
        if best_vocals:
            graph, engine = minimax_music3(style, lyrics, seconds, seed), "MiniMax Music 3"
        else:
            graph, engine = ace_step(style, lyrics, seconds, language, max(10, min(300, int(bpm))), key, seed), "ACE-Step 1.5"
        return await self._run(graph, engine, f"{seconds} s muzyki", seconds, __event_emitter__)

    async def generate_sound_effect(self, description: str, seconds: float = 3, __event_emitter__=None):
        """
        Generate a short sound effect or ambience (no music, no speech) and play it in the chat. Use it for game sounds, UI clicks, footsteps, nature, rain, impacts and similar.
        :param description: English description of the sound, e.g. "water pouring from a watering can onto soil" or "bright coin pickup chime, video game UI".
        :param seconds: Length in seconds, 1 to 30.
        """
        seconds = max(1.0, min(30.0, float(seconds)))
        graph = stable_audio3(description, seconds, random.randint(0, 2**31 - 1))
        return await self._run(graph, "Stable Audio 3", f"{seconds:g} s dźwięku", seconds, __event_emitter__)

    async def _run(self, graph, engine, what, seconds, __event_emitter__):
        async def status(text, done=False):
            if __event_emitter__:
                await __event_emitter__({"type": "status", "data": {"description": text, "done": done}})

        base = self.valves.comfyui_url.rstrip("/")
        timeout = aiohttp.ClientTimeout(total=30)

        await status(f"{engine}: wysyłam do ComfyUI na ragnaroku…")
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(f"{base}/prompt", json={"prompt": graph, "client_id": str(uuid.uuid4())}) as r:
                    body = await r.json(content_type=None)
                    if r.status != 200:
                        await status("Błąd ComfyUI", done=True)
                        return f"ComfyUI rejected the job: {body}"
                prompt_id = body["prompt_id"]

                loop = asyncio.get_running_loop()
                started = loop.time()
                while True:
                    await asyncio.sleep(3)
                    async with session.get(f"{base}/history/{prompt_id}") as r:
                        hist = await r.json(content_type=None)
                    if prompt_id in hist:
                        entry = hist[prompt_id]
                        if entry.get("status", {}).get("status_str") == "error":
                            await status("Błąd generowania", done=True)
                            return f"Generation failed: {entry['status'].get('messages', [])[-1:]}"
                        if entry.get("status", {}).get("completed"):
                            break
                    elapsed = int(loop.time() - started)
                    if elapsed > self.valves.timeout_seconds:
                        await status("Przekroczony czas", done=True)
                        return "Timed out waiting for ComfyUI."
                    progress = ""
                    try:
                        async with session.get(f"{base}/ragnarok/progress") as r:
                            p = await r.json(content_type=None)
                        if p.get("running") and p.get("max"):
                            progress = f" · {p.get('node')} {round(100 * p['value'] / p['max'])}%"
                    except (aiohttp.ClientError, ValueError):
                        pass
                    await status(f"{engine}: generuję {what} · {elapsed} s{progress}")

                audio = next(f for out in entry["outputs"].values() for f in out.get("audio", []))
                async with session.get(f"{base}/view", params={"filename": audio["filename"], "subfolder": audio["subfolder"], "type": "output"}) as r:
                    data = await r.read()
        except (aiohttp.ClientError, asyncio.TimeoutError) as e:
            await status("ComfyUI niedostępny", done=True)
            return f"ComfyUI on ragnarok is not reachable ({e}). It may be off or gaming."

        await status(f"{engine}: gotowe ({int(loop.time() - started)} s)", done=True)
        src = "data:audio/ogg;base64," + base64.b64encode(data).decode()
        name = html.escape(audio["filename"])
        page = f"""<!doctype html><html><body style="margin:0;font-family:system-ui,sans-serif;color:#888">
<audio controls style="width:100%" src="{src}"></audio>
<div style="font-size:12px;padding:4px 2px">{html.escape(engine)} · {seconds:g} s · <a href="{src}" download="{name}">pobierz</a></div>
</body></html>"""
        return (
            HTMLResponse(content=page, headers={"Content-Disposition": "inline"}),
            f"The {seconds:g}-second audio ({engine}) is generated and shown to the user as an audio player. Briefly tell the user it is ready; do not repeat the lyrics.",
        )
