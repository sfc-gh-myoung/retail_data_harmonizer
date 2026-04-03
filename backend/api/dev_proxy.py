"""Development reverse proxy – serves Vite dev server through FastAPI.

When enabled, all requests that do NOT match an existing API route (``/api/*``,
``/docs``, ``/openapi.json``) are forwarded to the Vite dev server running on
``VITE_DEV_URL`` (default ``http://localhost:5173``).  This lets the browser talk
to a single origin (port 8000), avoiding cross-port requests that enterprise
browsers like Palo Alto Prisma Access may block.

WebSocket connections (used by Vite HMR) are also proxied.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging
import os
from urllib.parse import urlparse

import httpx
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp, Receive, Scope, Send
from starlette.websockets import WebSocket

logger = logging.getLogger("retail_harmonizer.dev_proxy")

VITE_DEV_URL = os.getenv("VITE_DEV_URL", "http://localhost:5173")

_API_PREFIXES = ("/api/", "/docs", "/openapi.json", "/redoc")

_HOP_BY_HOP = frozenset(
    {
        "connection",
        "keep-alive",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailers",
        "transfer-encoding",
        "upgrade",
    }
)


def _should_proxy(path: str) -> bool:
    return not any(path.startswith(p) for p in _API_PREFIXES)


def _filtered_headers(
    headers: list[tuple[bytes, bytes]] | httpx.Headers,
) -> dict[str, str]:
    if isinstance(headers, httpx.Headers):
        return {
            k: v
            for k, v in headers.items()
            if k.lower() not in _HOP_BY_HOP
        }
    return {
        k.decode(): v.decode()
        for k, v in headers
        if k.decode().lower() not in _HOP_BY_HOP
    }


class ViteDevProxyMiddleware:
    """ASGI middleware that reverse-proxies non-API traffic to Vite."""

    def __init__(self, app: ASGIApp, vite_url: str = VITE_DEV_URL) -> None:  # noqa: D107
        self.app = app
        self.vite_url = vite_url.rstrip("/")
        parsed = urlparse(self.vite_url)
        self.vite_ws_url = f"ws://{parsed.hostname}:{parsed.port}"

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:  # noqa: D102
        if scope["type"] == "websocket" and _should_proxy(scope["path"]):
            await self._proxy_ws(scope, receive, send)
            return

        if scope["type"] == "http" and _should_proxy(scope["path"]):
            await self._proxy_http(scope, receive, send)
            return

        await self.app(scope, receive, send)

    async def _proxy_http(self, scope: Scope, receive: Receive, send: Send) -> None:
        request = Request(scope, receive)
        path = scope["path"]
        qs = scope.get("query_string", b"").decode()
        url = f"{self.vite_url}{path}"
        if qs:
            url = f"{url}?{qs}"

        body = await request.body()
        headers = _filtered_headers(scope["headers"])
        headers.pop("host", None)

        async with httpx.AsyncClient(timeout=30.0) as client:
            try:
                proxy_resp = await client.request(
                    method=request.method,
                    url=url,
                    headers=headers,
                    content=body,
                    follow_redirects=False,
                )
            except httpx.ConnectError:
                response = Response(
                    content="Vite dev server not running. Start it with: cd frontend/react && npm run dev",
                    status_code=502,
                    media_type="text/plain",
                )
                await response(scope, receive, send)
                return

        resp_headers = _filtered_headers(proxy_resp.headers)
        response = Response(
            content=proxy_resp.content,
            status_code=proxy_resp.status_code,
            headers=resp_headers,
            media_type=proxy_resp.headers.get("content-type"),
        )
        await response(scope, receive, send)

    async def _proxy_ws(self, scope: Scope, receive: Receive, send: Send) -> None:
        import websockets.asyncio.client as ws_client

        ws = WebSocket(scope, receive, send)
        path = scope["path"]
        qs = scope.get("query_string", b"").decode()
        target = f"{self.vite_ws_url}{path}"
        if qs:
            target = f"{target}?{qs}"

        await ws.accept()

        try:
            async with ws_client.connect(target) as upstream:

                async def client_to_upstream():
                    try:
                        while True:
                            data = await ws.receive_text()
                            await upstream.send(data)
                    except Exception:
                        pass

                async def upstream_to_client():
                    try:
                        async for msg in upstream:
                            if isinstance(msg, str):
                                await ws.send_text(msg)
                            else:
                                await ws.send_bytes(msg)
                    except Exception:
                        pass

                await asyncio.gather(client_to_upstream(), upstream_to_client())
        except Exception as exc:
            logger.debug("WebSocket proxy closed: %s", exc)
        finally:
            with contextlib.suppress(Exception):
                await ws.close()
