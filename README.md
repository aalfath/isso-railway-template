[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/isso-1?utm_medium=integration&utm_source=button&utm_campaign=isso)

# Isso on Railway

A Railway template for [Isso](https://isso-comments.de) 0.14.0, a lightweight self-hosted commenting server (a Disqus alternative) written in Python with a SQLite database.

## What it deploys

One service, `isso`, built from this repo's `Dockerfile`:

- Base image: the official `ghcr.io/isso-comments/isso:0.14.0`, pinned by digest `sha256:8e813ff52004f39c2c08237994450d3760515c4c6fa32faf61431bb280578e4e`.
- `start.sh` writes Isso's config from environment variables and starts gunicorn on `PORT`.
- `railway_wsgi.py` passes the visitor address that Railway's edge puts in `X-Real-IP` to Isso, so the per-IP spam guard and vote checks see real visitors instead of Railway's proxy.
- A volume at `/db` holds the SQLite database (`/db/comments.db`).
- Health check: `GET /info`.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `ISSO_HOST` | empty (optional) | Your website URL(s) that embed comments, e.g. `https://blog.example.com`. Several are allowed, separated by commas. Until you set it, only Isso's own `/demo/` page can post comments. |
| `ISSO_PUBLIC_ENDPOINT` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Isso's public URL, used in links, cookies and emails. |
| `ISSO_ADMIN_PASSWORD` | generated secret | Password for the moderation page at `/admin/`. Find it in the service's Variables tab. |
| `ISSO_HASH_SALT` | generated secret | Salt for the hashes Isso stores for commenter emails. Don't change it later. |
| `ISSO_MODERATION` | `false` | `true` holds new comments until you approve them in `/admin/`. |
| `PORT` | `8080` | Port gunicorn listens on. |

Optional settings read by `start.sh` (add them in the Variables tab when you need them): `ISSO_NAME`, `ISSO_MAX_AGE`, `ISSO_GRAVATAR`, `ISSO_LATEST_ENABLED`, `ISSO_REPLY_NOTIFICATIONS`, `ISSO_APPROVE_IF_EMAIL_PREVIOUSLY_APPROVED`, `ISSO_PURGE_AFTER`, `ISSO_SAMESITE`, `ISSO_GUARD_ENABLED`, `ISSO_GUARD_RATELIMIT`, `ISSO_GUARD_DIRECT_REPLY`, `ISSO_GUARD_REPLY_TO_SELF`, `ISSO_REQUIRE_AUTHOR`, `ISSO_REQUIRE_EMAIL`, `ISSO_RSS_BASE`, `ISSO_ADMIN_ENABLED` (default `true`), `WEB_CONCURRENCY` (gunicorn workers, default 2). Email notifications turn on when `ISSO_SMTP_HOST` is set, with `ISSO_SMTP_PORT`, `ISSO_SMTP_SECURITY`, `ISSO_SMTP_USERNAME`, `ISSO_SMTP_PASSWORD`, `ISSO_SMTP_FROM` and `ISSO_SMTP_TO`. Each maps to the Isso option of the same name in the [configuration docs](https://isso-comments.de/docs/reference/server-config/).

## Embed it in your site

```html
<script data-isso="https://YOUR-ISSO-DOMAIN/"
        src="https://YOUR-ISSO-DOMAIN/js/embed.min.js"></script>
<section id="isso-thread"></section>
```

## Updates

This template builds from this repo's `main` branch. When a new Isso release comes out, we bump the pinned image here and add an entry to `CHANGELOG.md`; Railway then shows an "update available" notice on your project, and you choose when to apply it. Read the changelog first: breaking changes are listed at the top of each entry. Your comments stay on the `/db` volume across updates.
