# Simple Ubuntu-based image with Ollama + ShellGPT
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
# Basis-Pakete in einem Layer
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        bash ca-certificates curl git python3 python3-pip vim zstd && \
    rm -rf /var/lib/apt/lists/*

# ---------- Install Ollama ----------
# Doku: https://docs.ollama.com/linux
RUN curl -fsSL https://ollama.com/install.sh | sh

# Non-root user
RUN groupadd -r ollama || true && useradd -m -s /bin/bash dev && usermod -a -G ollama dev
USER dev
WORKDIR /home/dev
ENV PATH="/home/dev/.local/bin:${PATH}"

# Start ollama server + Warten auf Health + pull im selben Layer
# Healthcheck = /api/tags; dann Modell ziehen
RUN bash -lc '\
  (ollama serve &); \
  for i in {1..100}; do \
    curl -sf http://localhost:11434/api/tags >/dev/null && break; \
    sleep 0.2; \
  done; \
  ollama pull phi3 \
'

# ---------- Install ShellGPT + LiteLLM bridge ----------
# sgpt nutzt für lokale Backends LiteLLM
RUN pip install --no-cache-dir "shell-gpt[litellm]"

# sgpt-Konfiguration für den USER *dev*
# Wichtig: USE_LITELLM=true, OPENAI_USE_FUNCTIONS=false, DEFAULT_MODEL=ollama/phi3
RUN mkdir -p /home/dev/.config/shell_gpt && \
    printf "USE_LITELLM=true\nOPENAI_USE_FUNCTIONS=false\nDEFAULT_MODEL=ollama/phi3\n" > /home/dev/.config/shell_gpt/.sgptrc

# (Optional) Wenn du explizit die OpenAI-kompatible /v1-API von Ollama nutzen willst:
# echo "API_BASE_URL=http://localhost:11434/v1" >> /home/dev/.config/shell_gpt/.sgptrc

ENV OPENAI_API_KEY=tux123

RUN printf "#!/usr/bin/env bash\nset -euo pipefail\n(ollama serve &)\nexec bash" > /home/dev/startup.sh

RUN chmod +x /home/dev/startup.sh

ENTRYPOINT ["/home/dev/startup.sh"]

