import contextlib
import io
import json
import socket
import threading
import unittest
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest import mock

import translate_stream as client


class TranslateStreamTests(unittest.TestCase):
    def routing_config(self, **overrides):
        config = {
            "local": {
                "base_url": "http://127.0.0.1:8080/v1",
                "endpoint": "/chat/completions",
                "model": "local-model",
                "timeout": 15,
            },
            "api": {
                "base_url": "https://api.example.test/v1",
                "endpoint": "/chat/completions",
                "api_key": "test-key",
                "model": "api-model",
                "timeout": 120,
            },
            "target_lang": "Chinese (Simplified)",
            "prompt": "Translate to ${target_lang}.",
            "stream": True,
            "allow_remote_fallback": True,
            "text": "hello",
        }
        config.update(overrides)
        return config

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

    def test_local_success_skips_remote_api(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), mock.patch(
            "translate_stream._run_route"
        ) as run_route:
            client.run(self.routing_config())

        run_route.assert_called_once()
        self.assertEqual(run_route.call_args.args[0].source, "local")
        events = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(events, [{"type": "done", "source": "local", "model": "local-model"}])

    def test_local_failure_falls_back_to_remote_api(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), mock.patch(
            "translate_stream._run_route",
            side_effect=[urllib.error.URLError(ConnectionRefusedError()), None],
        ) as run_route:
            client.run(self.routing_config())

        self.assertEqual(
            [call.args[0].source for call in run_route.call_args_list],
            ["local", "api"],
        )
        events = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual([event["type"] for event in events], ["fallback", "done"])
        self.assertEqual(events[0]["from_source"], "local")
        self.assertEqual(events[0]["to_source"], "api")
        self.assertEqual(events[1]["source"], "api")

    def test_local_partial_output_is_reset_before_remote_output(self):
        output = io.StringIO()

        def run_route(route, **_kwargs):
            client.emit("delta", source=route.source, text="partial-local")
            if route.source == "local":
                raise socket.timeout()
            return None

        with contextlib.redirect_stdout(output), mock.patch(
            "translate_stream._run_route", side_effect=run_route
        ):
            client.run(self.routing_config())

        events = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(
            [event["type"] for event in events],
            ["delta", "fallback", "delta", "done"],
        )
        self.assertEqual(events[0]["source"], "local")
        self.assertEqual(events[2]["source"], "api")

    def test_remote_fallback_can_be_disabled(self):
        with mock.patch(
            "translate_stream._run_route", side_effect=socket.timeout()
        ) as run_route:
            with self.assertRaisesRegex(client.TranslationError, "Local model failed"):
                client.run(self.routing_config(allow_remote_fallback=False))

        run_route.assert_called_once()
        self.assertEqual(run_route.call_args.args[0].source, "local")

    def test_remote_api_is_used_directly_without_local_model(self):
        config = self.routing_config()
        config["local"]["model"] = ""
        output = io.StringIO()
        with contextlib.redirect_stdout(output), mock.patch(
            "translate_stream._run_route"
        ) as run_route:
            client.run(config)

        run_route.assert_called_once()
        self.assertEqual(run_route.call_args.args[0].source, "api")
        event = json.loads(output.getvalue())
        self.assertEqual(event["source"], "api")

    def test_nested_routes_require_a_model(self):
        config = self.routing_config()
        config["local"]["model"] = ""
        config["api"]["model"] = ""
        with self.assertRaisesRegex(client.ConfigError, "Configure a local model"):
            client.run(config)

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

    def test_http_local_error_falls_back_to_remote_stream(self):
        received_paths = []

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                received_paths.append(self.path)
                length = int(self.headers["Content-Length"])
                self.rfile.read(length)
                if self.path.startswith("/local/"):
                    body = b'{"error":{"message":"model offline"}}'
                    self.send_response(503)
                    self.send_header("Content-Type", "application/json")
                else:
                    body = (
                        'data: {"choices":[{"delta":{"content":"remote-result"}}]}\n\n'
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
            base = f"http://127.0.0.1:{server.server_port}"
            config = self.routing_config()
            config["local"]["base_url"] = base + "/local/v1"
            config["api"]["base_url"] = base + "/api/v1"
            with contextlib.redirect_stdout(output):
                client.run(config)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

        events = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(received_paths, ["/local/v1/chat/completions", "/api/v1/chat/completions"])
        self.assertEqual(
            [event["type"] for event in events],
            ["meta", "fallback", "meta", "delta", "done"],
        )
        self.assertEqual(events[0]["source"], "local")
        self.assertEqual(events[2]["source"], "api")
        self.assertEqual(events[3]["source"], "api")
        self.assertEqual(events[4]["source"], "api")


if __name__ == "__main__":
    unittest.main()
