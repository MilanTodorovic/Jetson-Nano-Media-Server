# syntax=docker/dockerfile:1

# Jetson Nano can use Ubuntu 22.04 thru https://github.com/pythops/jetson-image/tree/master
#   However, cgroups v2 is bugged and Docker requires v2, so we can't use Docker at all.
#   There have been notes of a workaround by adding 'systemd.unified_cgroup_hierarchy=0'
#   to the extlinux.conf file, but that didn't work for me.
#   Might be a bug with the final version of Jetpack 4.6.6
#   https://github.com/NVIDIA/nvidia-container-toolkit/issues/137
FROM ghcr.io/linuxserver/baseimage-ubuntu:arm64v8-focal

# set version label
ARG JELLYFIN_RELEASE=10.11.6
LABEL maintainer="MilanTodorovic"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"
# https://github.com/dlemstra/Magick.NET/issues/707#issuecomment-785351620
ENV MALLOC_TRIM_THRESHOLD_=131072
ENV ATTACHED_DEVICES_PERMS="/dev/dri /dev/dvb /dev/vchiq /dev/vc-mem /dev/video1? -type c"

RUN \
  echo "**** install packages ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    gnupg && \
  echo "**** install jellyfin *****" && \
  curl -s https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | apt-key add - && \
  echo 'deb [arch=arm64] https://repo.jellyfin.org/ubuntu focal main' > /etc/apt/sources.list.d/jellyfin.list && \
  if [ -z ${JELLYFIN_RELEASE+x} ]; then \
    JELLYFIN_RELEASE=$(curl -sX GET https://repo.jellyfin.org/ubuntu/dists/focal/main/binary-arm64/Packages |grep -A 7 -m 1 'Package: jellyfin-server' | awk -F ': ' '/Version/{print $2;exit}'); \
  fi && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    at \
    libfontconfig1 \
    libfreetype6 \
    libjemalloc2 \
    libomxil-bellagio0 \
    libomxil-bellagio-bin \
    libraspberrypi0 \
    libssl1.1 \
    xmlstarlet && \
  apt-get install -y --no-install-recommends \
    alsa-lib-dev \
    aom-dev \
    bzip2-dev \
    coreutils \
    cunit-dev \
    dav1d-dev \
    fdk-aac-dev \
    ffmpeg-libs \
    fontconfig-dev \
    freetype-dev \
    fribidi-dev \
    gmp-dev \
    imlib2-dev \
    intel-media-driver-dev \
    intel-media-sdk-dev \
    ladspa-dev \
    lame-dev \
    libass-dev \
    libbluray-dev \
    libchromaprint-dev \
    libchromaprint-tools \
    libdrm-dev \
    libharfbuzz-dev \
    libogg-dev \
    libopenmpt-dev \
    libplacebo-dev \
    libpng-dev \
    librist-dev \
    libsrt-dev \
    libtheora-dev \
    libtool \
    libva-dev \
    libva-intel-driver \
    libvdpau-dev \
    libvdpau1 \
    libvorbis-dev \
    libvpx-dev \
    libwebp-dev \
    libxml2-dev \
    lilv-dev \
    mesa-dev \
    nasm \
    opencl-dev \
    openssl-dev \
    opus-dev \
    patch \
    perl-dev \
    rav1e-dev \
    shaderc-dev \
    svt-av1-dev \
    util-linux-dev \
    v4l-utils-dev \
    vulkan-loader-dev \
    vulkan-headers \
    vulkan-tools \
    x264-dev \
    x265-dev \
    xz-dev \
    zimg-dev \
    zlib-dev \
  apt-get install -y --no-install-recommends \
    jellyfin=${JELLYFIN_RELEASE} && \
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# add local files
COPY root/ / 

# Make a new directory and rename existing files
RUN \
  mkdir /usr/lib/jellyfin-ffmpeg/bin && \
  mv /usr/lib/jellyfin-ffmpeg/ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg.old && \
  mv /usr/lib/jellyfin-ffmpeg/ffprobe /usr/lib/jellyfin-ffmpeg/ffprobe.old

# Copy all both ffmpeg and ffprobe into the new destination
# This doesn't work outside of the build context, aka the current directiry
COPY $PATH_TO_FFMPEG/bin/ /usr/lib/jellyfin-ffmpeg/bin/

# Copy and rename the warpper
COPY scripts/ffmpeg-jetson-wrapper /usr/lib/jellyfin-ffmpeg/ffmpeg

# Make it executable
RUN chmod +x /usr/lib/jellyfin-ffmpeg/ffmpeg

# ports and volumes
EXPOSE 8096 8920
VOLUME /config
