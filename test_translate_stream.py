import contextlib
import io
import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest import mock

import translate_stream as client


class TranslateStreamTests(unittest.TestCase):
    def test_build_url_joins_openai_endpoint(self):
        self.assertEqual(
            client.build_url("http://127.0.0.1:8080/v1/", "/chat/completions"),
            "http://127.0.0.1:8080/v1/chat/completions",
        )

    def test_endpoint_may_be_full_url(self):
        self.assertEqual(
            client.build_url("", "https://example.test/custom/translate"),
            "https://example.test/custom/translate",
        )

    def test_runtime_errors_follow_ui_language(self):
        base = {"prompt": "Translate to ${target_lang}."}
        with self.assertRaisesRegex(client.ConfigError, "Selection is empty"):
            client.run({**base, "ui_language": "en"})
        with self.assertRaisesRegex(client.ConfigError, "划词内容为空"):
            client.run({**base, "ui_language": "zh"})

    def test_prompt_placeholder(self):
        self.assertEqual(
            client.render_prompt("Translate to ${target_lang}.", "简体中文"),
            "Translate to 简体中文.",
        )

    def test_detects_deepseek_requests(self):
        self.assertTrue(
            client.is_deepseek_request(
                "https://api.deepseek.com/v1/chat/completions",
                "deepseek-v4-flash",
            )
        )
        self.assertTrue(
            client.is_deepseek_request(
                "https://gateway.example.test/v1/chat/completions",
                "deepseek-v4-pro",
            )
        )
        self.assertFalse(
            client.is_deepseek_request(
                "https://api.openai.com/v1/chat/completions",
                "gpt-5-mini",
            )
        )

    def test_connection_resolves_ipv4_only(self):
        connection_socket = mock.Mock()
        resolved_address = ("192.0.2.10", 443)
        with mock.patch(
            "translate_stream.socket.getaddrinfo",
            return_value=[
                (
                    client.socket.AF_INET,
                    client.socket.SOCK_STREAM,
                    client.socket.IPPROTO_TCP,
                    "",
                    resolved_address,
                )
            ],
        ) as getaddrinfo, mock.patch(
            "translate_stream.socket.socket", return_value=connection_socket
        ):
            result = client._create_ipv4_connection(("api.example.test", 443), 5)

        getaddrinfo.assert_called_once_with(
            "api.example.test",
            443,
            client.socket.AF_INET,
            client.socket.SOCK_STREAM,
        )
        connection_socket.settimeout.assert_called_once_with(5)
        connection_socket.connect.assert_called_once_with(resolved_address)
        self.assertIs(result, connection_socket)

    def test_run_disables_thinking_for_deepseek(self):
        with contextlib.redirect_stdout(io.StringIO()), mock.patch(
            "translate_stream._request", return_value=True
        ) as request:
            client.run(
                {
                    "base_url": "https://api.deepseek.com/v1",
                    "endpoint": "/chat/completions",
                    "model": "deepseek-v4-flash",
                    "target_lang": "Chinese (Simplified)",
                    "prompt": "Translate to ${target_lang}.",
                    "stream": True,
                    "disable_thinking": True,
                    "text": "hello",
                }
            )

        payload = request.call_args.args[2]
        self.assertEqual(payload["thinking"], {"type": "disabled"})
        self.assertTrue(payload["stream"])

    def test_extract_stream_delta(self):
        data = {"choices": [{"delta": {"content": "你好"}}]}
        self.assertEqual(client.extract_choice_content(data), "你好")

    def test_extract_non_stream_message(self):
        data = {"choices": [{"message": {"content": "你好，世界"}}]}
        self.assertEqual(client.extract_choice_content(data), "你好，世界")

    def test_extract_list_content(self):
        data = {
            "choices": [
                {"message": {"content": [{"type": "text", "text": "译文"}]}}
            ]
        }
        self.assertEqual(client.extract_choice_content(data), "译文")

    def test_run_streams_ndjson_from_openai_sse(self):
        received = {}

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers["Content-Length"])
                received.update(json.loads(self.rfile.read(length)))
                body = (
                    'data: {"choices":[{"delta":{"content":"你"}}]}\n\n'
                    'data: {"choices":[{"delta":{"content":"好"}}]}\n\n'
                    "data: [DONE]\n\n"
                ).encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *_args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        output = io.StringIO()
        try:
            with contextlib.redirect_stdout(output):
                client.run(
                    {
                        "base_url": f"http://127.0.0.1:{server.server_port}/v1",
                        "endpoint": "/chat/completions",
                        "model": "mock-model",
                        "target_lang": "Chinese (Simplified)",
                        "prompt": "Translate to ${target_lang}.",
                        "stream": True,
                        "text": "hello",
                    }
                )
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

        events = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual([event["type"] for event in events], ["meta", "delta", "delta", "done"])
        self.assertEqual("".join(event.get("text", "") for event in events), "你好")
        self.assertTrue(received["stream"])
        self.assertEqual(received["model"], "mock-model")
        self.assertEqual(received["messages"][0]["content"], "Translate to Chinese (Simplified).")


if __name__ == "__main__":
    unittest.main()
