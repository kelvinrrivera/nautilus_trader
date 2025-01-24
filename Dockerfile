# Build stage
FROM python:3.11-slim-bookworm as builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Poetry
ENV POETRY_VERSION=1.8.2
RUN pip install "poetry==$POETRY_VERSION"

# Copy dependency files
COPY pyproject.toml poetry.lock ./

# Install dependencies
RUN poetry config virtualenvs.in-project true && \
    poetry install --only main --no-root

# Copy application code
COPY . .

# Build the project
RUN poetry install --only-root

# Runtime stage
FROM python:3.11-slim-bookworm

WORKDIR /app

# Copy Python dependencies
COPY --from=builder /app/.venv ./.venv
COPY --from=builder /app/nautilus_trader ./nautilus_trader
COPY --from=builder /app/nautilus_core ./nautilus_core

# Set environment variables
ENV PATH="/app/.venv/bin:${PATH}"
ENV PYTHONPATH="/app:${PYTHONPATH}"
ENV NAUTILUS_ENV=production

# Expose ports
EXPOSE 8000 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default command
CMD ["nautilus", "run"]
