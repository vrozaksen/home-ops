#!/usr/bin/env python3
"""whisper-asr-webservice API in front of whisper.cpp's OpenAI endpoint.

Bazarr's Whisper provider (custom_libs/subliminal_patch/providers/whisperai.py)
does not speak the OpenAI shape. It POSTs *headerless* 16 kHz mono s16le PCM
(that is what `encode=false` means) to two endpoints and expects:

    POST /asr?task=&language=&output=srt   -> the subtitle body, as-is
    POST /detect-language                  -> {"language_code", "detected_language"}

whisper.cpp's server only offers /v1/audio/transcriptions. This translates
between the two so one whisper deployment serves both Bazarr and MinusPod.

Standard library only, so it runs on a plain python image with the file
mounted from a ConfigMap.
"""
import json
import os
import re
import struct
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

UPSTREAM = os.environ.get("WHISPER_UPSTREAM", "http://127.0.0.1:8765")
INFERENCE_PATH = os.environ.get("WHISPER_INFERENCE_PATH", "/v1/audio/transcriptions")
PORT = int(os.environ.get("PORT", "9000"))
# A whole movie can sit in the queue behind another one, so this is generous.
TIMEOUT = int(os.environ.get("WHISPER_TIMEOUT", "14400"))

SAMPLE_RATE = 16000
BYTES_PER_SAMPLE = 2
# Whisper names the language from its first encoder window and nothing else, so
# the shim trims to that before forwarding. Without this, /detect-language costs
# a full transcription -- whisper.cpp has no detect-only path.
DETECT_BYTES = 30 * SAMPLE_RATE * BYTES_PER_SAMPLE

# whisper.cpp answers with the long language name ("polish"); Bazarr wants the
# code as well. Generated from g_lang in whisper.cpp/src/whisper.cpp.
NAME_TO_CODE = {
    "english": "en", "chinese": "zh", "german": "de", "spanish": "es", "russian": "ru",
    "korean": "ko", "french": "fr", "japanese": "ja", "portuguese": "pt", "turkish": "tr",
    "polish": "pl", "catalan": "ca", "dutch": "nl", "arabic": "ar", "swedish": "sv",
    "italian": "it", "indonesian": "id", "hindi": "hi", "finnish": "fi", "vietnamese": "vi",
    "hebrew": "he", "ukrainian": "uk", "greek": "el", "malay": "ms", "czech": "cs",
    "romanian": "ro", "danish": "da", "hungarian": "hu", "tamil": "ta", "norwegian": "no",
    "thai": "th", "urdu": "ur", "croatian": "hr", "bulgarian": "bg", "lithuanian": "lt",
    "latin": "la", "maori": "mi", "malayalam": "ml", "welsh": "cy", "slovak": "sk",
    "telugu": "te", "persian": "fa", "latvian": "lv", "bengali": "bn", "serbian": "sr",
    "azerbaijani": "az", "slovenian": "sl", "kannada": "kn", "estonian": "et",
    "macedonian": "mk", "breton": "br", "basque": "eu", "icelandic": "is", "armenian": "hy",
    "nepali": "ne", "mongolian": "mn", "bosnian": "bs", "kazakh": "kk", "albanian": "sq",
    "swahili": "sw", "galician": "gl", "marathi": "mr", "punjabi": "pa", "sinhala": "si",
    "khmer": "km", "shona": "sn", "yoruba": "yo", "somali": "so", "afrikaans": "af",
    "occitan": "oc", "georgian": "ka", "belarusian": "be", "tajik": "tg", "sindhi": "sd",
    "gujarati": "gu", "amharic": "am", "yiddish": "yi", "lao": "lo", "uzbek": "uz",
    "faroese": "fo", "haitian creole": "ht", "pashto": "ps", "turkmen": "tk",
    "nynorsk": "nn", "maltese": "mt", "sanskrit": "sa", "luxembourgish": "lb",
    "myanmar": "my", "tibetan": "bo", "tagalog": "tl", "malagasy": "mg", "assamese": "as",
    "tatar": "tt", "hawaiian": "haw", "lingala": "ln", "hausa": "ha", "bashkir": "ba",
    "javanese": "jw", "sundanese": "su", "cantonese": "yue",
}
CODES = set(NAME_TO_CODE.values())

# Bazarr only ever asks for srt, but the provider is configurable.
OUTPUT_TO_FORMAT = {
    "srt": "srt", "vtt": "vtt", "txt": "text", "text": "text",
    "json": "json", "verbose_json": "verbose_json",
}


def wav(pcm):
    """Give raw s16le mono PCM the 44-byte header whisper.cpp needs."""
    n = len(pcm)
    fmt = struct.pack(
        "<IHHIIHH", 16, 1, 1, SAMPLE_RATE,
        SAMPLE_RATE * BYTES_PER_SAMPLE, BYTES_PER_SAMPLE, 16,
    )
    return (b"RIFF" + struct.pack("<I", 36 + n) + b"WAVEfmt " + fmt
            + b"data" + struct.pack("<I", n) + pcm)


def parse_multipart(body, content_type):
    """Pull the named parts out of a multipart/form-data body."""
    match = re.search(r'boundary="?([^";]+)"?', content_type or "")
    if not match:
        return {}
    fields = {}
    for chunk in body.split(b"--" + match.group(1).encode()):
        head, sep, data = chunk.partition(b"\r\n\r\n")
        if not sep:
            continue
        name = re.search(rb'name="([^"]+)"', head)
        if name:
            fields[name.group(1).decode()] = data[:-2] if data.endswith(b"\r\n") else data
    return fields


def build_multipart(audio, form):
    boundary = "----whispershim" + os.urandom(8).hex()
    parts = []
    for key, value in form.items():
        parts.append(
            ("--{}\r\nContent-Disposition: form-data; name=\"{}\"\r\n\r\n{}\r\n"
             .format(boundary, key, value)).encode()
        )
    parts.append(
        ("--{}\r\nContent-Disposition: form-data; name=\"file\"; "
         "filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n"
         .format(boundary)).encode()
    )
    parts.append(audio)
    parts.append(("\r\n--{}--\r\n".format(boundary)).encode())
    return b"".join(parts), "multipart/form-data; boundary=" + boundary


def transcribe(pcm, form):
    body, content_type = build_multipart(wav(pcm), form)
    request = urllib.request.Request(
        UPSTREAM + INFERENCE_PATH, data=body,
        headers={"Content-Type": content_type, "Content-Length": str(len(body))},
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return response.read()


def language_of(query):
    """Bazarr's alpha-2 code, or 'auto'. An unknown code would make whisper.cpp
    reject the whole request, so it degrades to detection instead."""
    value = (query.get("language") or [""])[0].strip().lower()
    return value if value in CODES else "auto"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "whisper-bazarr-shim"

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)

    def reply(self, status, body, content_type):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def reply_json(self, status, payload):
        self.reply(status, json.dumps(payload).encode(), "application/json")

    def do_GET(self):
        if urlparse(self.path).path != "/health":
            self.reply_json(404, {"error": "not found"})
            return
        try:
            with urllib.request.urlopen(UPSTREAM + "/health", timeout=10) as response:
                self.reply(200, response.read(), "application/json")
        except (urllib.error.URLError, OSError) as exc:
            self.reply_json(503, {"error": "upstream unreachable: %s" % exc})

    def do_POST(self):
        route = urlparse(self.path)
        query = parse_qs(route.query)
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            self.reply_json(400, {"error": "bad Content-Length"})
            return
        fields = parse_multipart(self.rfile.read(length), self.headers.get("Content-Type"))
        pcm = fields.get("audio_file")
        if not pcm:
            self.reply_json(400, {"error": "no 'audio_file' field in the request"})
            return

        try:
            if route.path == "/detect-language":
                raw = transcribe(pcm[:DETECT_BYTES],
                                 {"detect_language": "true", "response_format": "json"})
                name = (json.loads(raw).get("language") or "").lower()
                self.reply_json(200, {
                    "detected_language": name,
                    "language_code": NAME_TO_CODE.get(name, "und"),
                })
            elif route.path == "/asr":
                output = (query.get("output") or ["srt"])[0].lower()
                form = {
                    "response_format": OUTPUT_TO_FORMAT.get(output, "srt"),
                    "language": language_of(query),
                }
                if (query.get("task") or ["transcribe"])[0] == "translate":
                    form["translate"] = "true"
                self.reply(200, transcribe(pcm, form), "text/plain; charset=utf-8")
            else:
                self.reply_json(404, {"error": "not found"})
        except urllib.error.HTTPError as exc:
            self.reply(exc.code, exc.read() or b"{}", "application/json")
        except (urllib.error.URLError, OSError, ValueError) as exc:
            self.reply_json(502, {"error": "upstream failed: %s" % exc})


if __name__ == "__main__":
    print("shim on :%d -> %s%s" % (PORT, UPSTREAM, INFERENCE_PATH), flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
