from http.server import BaseHTTPRequestHandler
import asyncio
import json
import io
import edge_tts


class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body.decode("utf-8"))

            text = data.get("text", "")
            voice = data.get("voice", "es-ES-AlvaroNeural")
            audio_format = data.get("format", "mp3").lower()

            if not text:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps({"error": "El campo 'text' es obligatorio"}).encode()
                )
                return

            # Validate format
            format_map = {
                "mp3": ("audio/mpeg", "mp3"),
                "wav": ("audio/wav", "wav"),
                "ogg": ("audio/ogg", "ogg"),
            }

            if audio_format not in format_map:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {"error": f"Formato no soportado: {audio_format}. Usa: mp3, wav, ogg"}
                    ).encode()
                )
                return

            content_type, file_ext = format_map[audio_format]
            audio_bytes = asyncio.run(self._generate_audio(text, voice))

            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header(
                "Content-Disposition", f'attachment; filename="tts_audio.{file_ext}"'
            )
            self.send_header("Content-Length", str(len(audio_bytes)))
            self.end_headers()
            self.wfile.write(audio_bytes)

        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    @staticmethod
    async def _generate_audio(text: str, voice: str) -> bytes:
        communicate = edge_tts.Communicate(text, voice)
        buffer = io.BytesIO()
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                buffer.write(chunk["data"])
        return buffer.getvalue()
