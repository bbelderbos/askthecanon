FROM python:3.14-slim

# pango and harfbuzz are required by weasyprint for the PDF export
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz-subset0 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.12.22 /uv /usr/local/bin/uv

RUN useradd --create-home app && install -d -o app -g app /app
USER app
WORKDIR /app

ENV UV_NO_CACHE=1 \
    UV_PYTHON_DOWNLOADS=never \
    HF_HOME=/app/.hf \
    PYTHONUNBUFFERED=1 \
    PATH=/app/.venv/bin:$PATH

COPY .python-version pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project
RUN python -c "from sentence_transformers import SentenceTransformer as S; S('all-mpnet-base-v2')"

# COPY ignores USER, and sync has to write to books/
COPY --chown=app:app . .
# books/ is untracked: index it before building, or the image ships with nothing to search
RUN python main.py check

EXPOSE 8000
CMD ["uvicorn", "web:app", "--host", "0.0.0.0", "--port", "8000"]
