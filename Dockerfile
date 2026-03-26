# syntax=docker/dockerfile:1

# Jetson Nano can use Ubuntu 22.04 thru https://github.com/pythops/jetson-image/tree/master
#   However, cgroups v2 is bugged and Docker requires v2, so we can't use Docker at all.
#   There have been notes of a workaround by adding 'systemd.unified_cgroup_hierarchy=0'
#   to the extlinux.conf file, but that didn't work for me.
#   Might be a bug with the final version of Jetpack 4.6.6
#   https://github.com/NVIDIA/nvidia-container-toolkit/issues/137
FROM ghcr.io/linuxserver/baseimage-ubuntu:arm64v8-focal

# set version label
ARG JELLYFIN_RELEASE
LABEL maintainer="MilanTodorovic"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"
# https://github.com/dlemstra/Magick.NET/issues/707#issuecomment-785351620
ENV MALLOC_TRIM_THRESHOLD_=131072
ENV ATTACHED_DEVICES_PERMS="/dev/dri /dev/dvb /dev/vchiq /dev/vc-mem /dev/video1? -type c"

RUN \
  echo "**** adding nvidia sources to apt ****" && \
  echo 'deb http://ports.ubuntu.com/ubuntu-ports/ bionic main' >> /etc/apt/sources.list && \
  echo 'deb https://repo.download.nvidia.com/jetson/common r32.7 main' >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
  echo 'deb https://repo.download.nvidia.com/jetson/t210 r32.7 main' >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
  echo "**** install prerequisties ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    gnupg && \
  echo "**** install jellyfin key*****" && \
  curl -s https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | apt-key add - && \
  echo 'deb [arch=arm64] https://repo.jellyfin.org/ubuntu focal main' > /etc/apt/sources.list.d/jellyfin.list && \
  echo "**** install packages ****" && \
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
# Installing FFmpeg dependencies
  apt-get install -y --no-install-recommends \
    libass9 \
    libasound2 \
    libbz2-1.0 \
    libc6 \
    libchromaprint1 \
    libdrm-common \
    libdrm2 \
    libfontconfig1 \
    libfreetype6 \
    libfribidi0 \
    libharfbuzz0b \
    libopenmpt0 \
    libva2 \
    libxml2 \
    libbluray2 \
    libgmp10 \
    libgnutls30 \
    libvpx6 \
    libwebpmux3 \
    libwebp6 \
    liblzma5 \
    libzvbi0 \
    libfdk-aac1 \
    libmp3lame0 \
    libopus0 \
    libtheora0 \
    libvorbis0a \
    libvorbisenc2 \
    libx264-155 \
    libx265-179 \
    libva-drm2 \
    libvdpau1 \
    libx11-6 \
    libglib2.0-0 \
    libgraphite2-3 \
    libstdc++6 \
    libgcc-s1 \
    libexpat1 \
    libuuid1 \
    libpng16-16 \
    libicu66 \
    libmpg123-0 \
    libvorbisfile3 \
    libavcodec58 \
    libavutil56 \
    libp11-kit0 \
    libidn2-0 \
    libunistring2 \
    libtasn1-6 \
    libnettle7 \
    libhogweed5 \
    libogg0 \
    libcairo2 \
    libnuma1 \
    libxext6 \
    libxcb1 \
    libpcre3 \
    libswresample3 \
    librsvg2-2 \
    libsnappy1v5 \
    libaom0 \
    libcodec2-0.9 \
    libgsm1 \
    libopenjp2-7 \
    libshine3 \
    libspeex1 \
    libtwolame0 \
    libwavpack1 \
    libxvidcore4 \
    libva-x11-2 \
    libffi7 \
    libegl1 \
    libpixman-1-0 \
    libxcb-shm0 \
    libxcb-render0 \
    libxrender1 \
    libxau6 \
    libxdmcp6 \
    libsoxr0 \
    libcairo-gobject2 \
    libgdk-pixbuf2.0-0 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libpangoft2-1.0-0 \
    libxfixes3 \
    libglvnd0 \
    libbsd0 \
    libgomp1 \
    libmount1 \
    libselinux1 \
    libthai0 \
    libblkid1 \
    libpcre2-8-0 \
    libdatrie1 \
    nvidia-l4t-core \
    nvidia-l4t-multimedia \
    nvidia-l4t-multimedia-utils \
    ocl-icd-libopencl1 \
    zlib1g && \
  wget https://repo.download.nvidia.com/jetson/t210/pool/main/n/nvidia-l4t-jetson-multimedia-api/nvidia-l4t-jetson-multimedia-api_32.7.6-20241104234540_arm64.deb && \
  dpkg -i nvidia-l4t-jetson-multimedia-api_32.7.6-20241104234540_arm64.deb && \
  
  if [ -z ${JELLYFIN_RELEASE+x} ]; then \
    JELLYFIN_RELEASE=$(curl -sX GET https://repo.jellyfin.org/ubuntu/dists/focal/main/binary-arm64/Packages |grep -A 7 -m 1 'Package: jellyfin-server' | awk -F ': ' '/Version/{print $2;exit}'); \
  fi && \
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
