# Isso packaged for Railway.
# Official image, pinned by release tag and multi-arch index digest.
FROM ghcr.io/isso-comments/isso:0.14.0@sha256:8e813ff52004f39c2c08237994450d3760515c4c6fa32faf61431bb280578e4e

# railway_wsgi.py: passes Railway's X-Real-IP (set by Railway's edge, not by the
# client) to Isso, so the per-IP spam guard and vote checks see real visitors.
# isso-railway-start: writes isso.cfg from environment variables, then runs gunicorn.
COPY railway_wsgi.py /isso/railway_wsgi.py
COPY start.sh /usr/local/bin/isso-railway-start
RUN chmod 0755 /usr/local/bin/isso-railway-start \
 && sh -n /usr/local/bin/isso-railway-start \
 && /isso/bin/python -c "import isso, isso.config; print('isso', isso.__version__ if hasattr(isso, '__version__') else '')"

ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/isso-railway-start"]
