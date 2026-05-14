ARG BASE_IMAGE=nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04
FROM ${BASE_IMAGE}

ARG COMFYUI_VERSION=latest
ARG CUDA_VERSION_FOR_COMFY=12.1
ARG WORKER_COMFYUI_REF=d2a557235b3800d68dcc6fa3259125fdf4bed8a6

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_PREFER_BINARY=1
ENV PYTHONUNBUFFERED=1
ENV CMAKE_BUILD_PARALLEL_LEVEL=8
ENV PATH="/opt/venv/bin:${PATH}"

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    wget \
    ca-certificates \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    openssh-server \
    libgoogle-perftools4 \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

RUN wget -qO- https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

RUN uv pip install comfy-cli pip setuptools wheel runpod~=1.7.12 websocket-client requests

RUN /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --cuda-version "${CUDA_VERSION_FOR_COMFY}" --nvidia

RUN git clone https://github.com/runpod-workers/worker-comfyui.git /tmp/worker-comfyui \
    && cd /tmp/worker-comfyui \
    && git checkout "${WORKER_COMFYUI_REF}" \
    && install -m 755 scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode \
    && install -m 755 scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install \
    && install -m 755 src/start.sh /start.sh \
    && install -m 644 src/network_volume.py /network_volume.py \
    && install -m 644 handler.py /handler.py

WORKDIR /comfyui

RUN comfy-node-install \
    https://github.com/kijai/ComfyUI-KJNodes.git \
    https://github.com/kijai/ComfyUI-WanVideoWrapper.git \
    https://github.com/kijai/ComfyUI-MelBandRoFormer.git \
    comfyui-videohelpersuite@1.7.7

WORKDIR /

COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml
COPY input/ /comfyui/input/

CMD ["/start.sh"]
