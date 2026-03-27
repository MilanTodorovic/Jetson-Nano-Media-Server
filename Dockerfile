# syntax=docker/dockerfile:1

# Jetson Nano can use Ubuntu 22.04 thru https://github.com/pythops/jetson-image/tree/master
#   However, cgroups v2 is bugged and Docker requires v2, so we can't use Docker at all.
#   There have been notes of a workaround by adding 'systemd.unified_cgroup_hierarchy=0'
#   to the extlinux.conf file, but that didn't work for me.
#   Might be a bug with the final version of Jetpack 4.6.6
#   https://github.com/NVIDIA/nvidia-container-toolkit/issues/137
FROM ghcr.io/linuxserver/baseimage-ubuntu:arm64v8-focal

ENV TZ=Etc/UTC \
    DEBIAN_FRONTEND=noninteractive \
    NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
    # https://github.com/dlemstra/Magick.NET/issues/707#issuecomment-785351620
    MALLOC_TRIM_THRESHOLD_=131072 \
    ATTACHED_DEVICES_PERMS="/dev/dri /dev/dvb /dev/vchiq /dev/vc-mem /dev/video1? -type c"

# Install systemd
RUN apt update && apt install -y systemd && \
# Update apt mirrors
# Nvidia required packages
    echo "deb http://ports.ubuntu.com/ubuntu-ports/ bionic main" >> /etc/apt/sources.list && \
    apt update && apt install -y \
        libgles2 \
        libpangoft2-1.0-0 \
        libxkbcommon0 \
        libwayland-egl1 \
        libwayland-cursor0 \
        libunwind8 \
        libasound2 \
        libpixman-1-0 \
        libjpeg-turbo8 \
        libinput10 \
        libcairo2 \
        device-tree-compiler \
        iso-codes \
        libffi6 \
        libncursesw5 \
        libdrm-common \
        libdrm2 \
        libegl-mesa0 \
        libegl1 \
        libegl1-mesa \
        libgtk-3-0 \
        python2 \
        python-is-python2 \
        libgstreamer1.0-0 \
        libgstreamer-plugins-bad1.0-0 \
        i2c-tools \
        bridge-utils && \
# Additional tools
    apt install -y \
        bash-completion \
        build-essential \
        btrfs-progs \
        ca-certificates \
        cmake \
        curl \
        dnsutils \
        gnupg2 \
        htop \
        iotop \
        isc-dhcp-client \
        iputils-ping \
        kmod \
        linux-firmware \
        locales \
        net-tools \
        netplan.io \
        pciutils \
        python3-dev \
        samba \
        ssh \
        sudo \
        udev \
        unzip \
        usbutils \
        neovim \
        wpasupplicant \
        parted \
        gdisk \
        e2fsprogs \
        mtd-utils

# Add Nvidia specific repos
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list && \
    echo "deb https://repo.download.nvidia.com/jetson/common r32.7 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    echo "deb https://repo.download.nvidia.com/jetson/t210 r32.7 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    # Nvidia containers
    apt update && apt install -y \
        docker.io \
        docker-compose-v2 \
        libnvidia-container-tools \
        libnvidia-container1:arm64 \
        nvidia-container-toolkit-base \
        nvidia-container-toolkit \
        nvidia-docker2 \
        nvidia-l4t-multimedia \
        nvidia-l4t-multimedia-utils \
        cuda-toolkit-10-2 && \
# Configure Docker file with Nvidia's parameters
    nvidia-ctk runtime configure --runtime=docker && \
    sudo apt update && sudo apt -y install \
        autoconf \
        automake \
        clang \
        git-core \
        gnutls-bin \
        libass-dev \
        libbluray-dev \
        libchromaprint-dev \
        libchromaprint-tools \
        libfreetype6-dev \
        libgmp-dev \
        libgnutls28-dev \
        libmp3lame-dev \
        libtool \
        libvorbis-dev \
        libmp3lame-dev \
        libopenmpt-dev \
        libopus-dev \
        libfdk-aac-dev \
        meson \
        ninja-build \
        pkg-config \
        opencl-headers \
        ocl-icd-opencl-dev \
        libtheora-dev \
        libvpx-dev \
        libwebp-dev \
        libx264-dev \
        libx265-dev \
        libzvbi-dev \
        libdrm-dev \
        texinfo \
        wget \
        yasm \
        zlib1g-dev && \
        pkg-config --modversion gnutls

RUN wget -q https://github.com/pythops/tegratop/releases/latest/download/tegratop-linux-arm64 -O /usr/local/bin/tegratop && \
    chmod +x /usr/local/bin/tegratop && \
    wget https://repo.download.nvidia.com/jetson/t210/pool/main/n/nvidia-l4t-jetson-multimedia-api/nvidia-l4t-jetson-multimedia-api_32.7.6-20241104234540_arm64.deb && \
    dpkg -i nvidia-l4t-jetson-multimedia-api_32.7.6-20241104234540_arm64.deb && \
    rm nvidia-l4t-jetson-multimedia-api_32.7.6-20241104234540_arm64.deb

# Installing Jellyfin and stuff
RUN \
  curl -s https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor | tee /usr/share/keyrings/jellyfin.gpg >/dev/null && \
  echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/jellyfin.gpg] https://repo.jellyfin.org/ubuntu noble main' > /etc/apt/sources.list.d/jellyfin.list && \
  if [ -z ${JELLYFIN_RELEASE+x} ]; then \
    JELLYFIN_RELEASE=$(curl -sX GET https://repo.jellyfin.org/ubuntu/dists/noble/main/binary-amd64/Packages |grep -A 7 -m 1 'Package: jellyfin-server' | awk -F ': ' '/Version/{print $2;exit}'); \
  fi && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    at \
    libjemalloc2 \
    libomxil-bellagio0 \
    libomxil-bellagio-bin \
    libraspberrypi0 \
    xmlstarlet && \
  apt-get install -y --no-install-recommends \
    jellyfin=${JELLYFIN_RELEASE}

# FFmpeg stuff
RUN git clone --depth=1 https://github.com/Keylost/jetson-ffmpeg.git && \
    git clone --depth=1 https://github.com/jellyfin/jellyfin-ffmpeg.git && \
    git clone --depth=1 https://code.videolan.org/videolan/dav1d.git && \
    git clone --depth=1 https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
    git clone --depth=1 https://git.videolan.org/git/ffmpeg/nv-codec-headers.git && \
    git clone --depth=1 --recurse-submodules https://github.com/sekrit-twc/zimg.git && \
    wget https://code.ffmpeg.org/FFmpeg/FFmpeg/pulls/21567.patch && \
    wget https://raw.githubusercontent.com/mattangus/jellyfin/refs/heads/master/scripts/ffmpeg-jetson-wrapper

# Make and install all additional dependencies
# TODO: CONFIGURE INSTALLATION PATH AS IT IS NOT EMPTY
RUN echo "Building zimg" && \
    cd zimg/ && \
    git submodule update --init --recursive && \
    ./autogen.sh && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    echo "Building dav1d" && \
    cd dav1d/ && \
    meson build && \
    cd build && \
    ninja && ninja install && \
    cg / && \
    echo "Building svt-av1" && \
    cd SVT-AV1/Build/linux && \
    ./build.sh release && \
    cd Release && make install && \
    chmod +x /usr/local/bin/SvtAv1EncApp && \
    cd / && \
    echo "Building nv-codec-headers" && \
    cd nv-codec-headers/ && \
    make install && \
    cd / && \
    echo "Patching jellyfin-ffmpeg" && \
    mv ./21567.patch jellyfin-ffmpeg/ && \
    cd jellyfin-ffmpeg/ && \
    git apply ./21567.patch && \
    cd / && \
    echo "Changing ffmpeg and ffprobe to ffmpeg.old and ffprobe.old" && \
    mv /usr/lib/jellyfin-ffmpeg/ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg.old && \
    mv /usr/lib/jellyfin-ffmpeg/ffprobe /usr/lib/jellyfin-ffmpeg/ffmprobe.old && \
    echo "Setting up jetson-ffmpeg" && \
    cd jetson-ffmpeg/ && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    echo "Compiling jellyfin-ffmpeg" && \
    ./configure --prefix=/usr/lib/jellyfin-ffmpeg --target-os=linux --extra-version=Jellyfin --disable-static --enable-shared --enable-nonfree --disable-doc --disable-ffplay --disable-libxcb --disable-sdl2 --disable-xlib --enable-lto=auto --enable-gpl --enable-version3  --enable-gmp --enable-gnutls --enable-chromaprint --enable-opencl --enable-libdrm --enable-libxml2 --enable-libass --enable-libfreetype --enable-libfribidi --enable-libfontconfig --enable-libharfbuzz --enable-libbluray --enable-libmp3lame --enable-libopus --enable-libtheora --enable-libvorbis --enable-libopenmpt --enable-libdav1d --enable-libsvtav1 --enable-libwebp --enable-libvpx --enable-libx264 --enable-libx265 --enable-libzvbi --enable-libzimg --enable-libfdk-aac --arch=arm64 --toolchain=hardened  --enable-ffnvcodec --enable-cuda --enable-cuda-llvm --extra-cflags="-I/usr/local/cuda/include" --extra-ldflags=-L/usr/local/cuda/lib64 --enable-cuvid --enable-nvdec --enable-nvenc --enable-nvmpi && \
    make -j$(nproc) && make install && \
    mv /usr/lib/jellyfin-ffmpeg/ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg.new && \
    mv /usr/lib/jellyfin-ffmpeg/ffprobe /usr/lib/jellyfin-ffmpeg/ffmprobe.new && \
    chmod +x /usr/lib/jellyfin-ffmpeg/ffmpeg.new && \
    chmod +x /usr/lib/jellyfin-ffmpeg/ffprobe.new && \
    cd / && \
    chmod +x ./ffmpeg-jetson-wrapper && \
    mv ./ffmpeg-jetson-wrapper ./ffmpeg && \
    sed 's/ffprobe/ffprobe.new/' ./ffmpeg && \
    sed 's/ffmpeg/ffmpeg.new/' ./ffmpeg && \
    mv ./ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg

RUN  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# add local files
COPY root/ /

# ports and volumes
EXPOSE 8096 8920
VOLUME /config
