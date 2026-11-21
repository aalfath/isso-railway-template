"""WSGI entry point for Isso on Railway.

Railway's edge sends "X-Forwarded-For: <client>, <edge hop>", and Isso's
ProxyFix trusts one hop, so without this every commenter would look like a
rotating Railway address. Railway's edge overwrites X-Real-IP with the real
client address, so we hand that to Isso as the forwarded address.
"""
from isso.run import application as _isso


def application(environ, start_response):
    real_ip = (environ.get("HTTP_X_REAL_IP") or "").strip()
    if real_ip:
        environ["HTTP_X_FORWARDED_FOR"] = real_ip
    return _isso(environ, start_response)
