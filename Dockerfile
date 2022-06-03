FROM nvidia/cuda:11.3.0-cudnn8-devel-ubuntu18.04
# Ubuntu 18.04.5 LTS
# CUDA 10.0.130
# cuDNN 7.6.05

# install required Ubuntu packages
# RUN apt-key del 7fa2af80 && \
#     apt-key del F60F4B3D7FA2AF80 && \
#     apt-key del f60f4b3d && \
#     apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub && \
#     rm /etc/apt/sources.list.d/nvidia-ml.list

RUN apt-get update && DEBIAN_FRONTEND="noninteractive" apt-get install -y \
   # OpenPose
   lsb-release sudo git libopencv-dev \
   # Skeleton Group Activity Recognition
   libgl1-mesa-glx python3-dev python3-pip wget

WORKDIR /cmake/
RUN wget https://github.com/Kitware/CMake/releases/download/v3.15.6/cmake-3.15.6.tar.gz && \
    tar -zxvf cmake-3.15.6.tar.gz && \
    cd cmake-3.15.6 && \
    ./bootstrap && \
    make -j`nproc` && \
    sudo make install -j`nproc`

#
# OpenPose
#
# compile OpenPose from source
WORKDIR /openpose/
RUN git clone https://github.com/CMU-Perceptual-Computing-Lab/openpose . && \
    apt-get install -y libopencv-dev && \
    bash ./scripts/ubuntu/install_deps.sh && \
    cd /openpose/3rdparty/ && \
    git clone https://github.com/CMU-Perceptual-Computing-Lab/caffe.git && \
    git clone https://github.com/pybind/pybind11 

WORKDIR /openpose/build
ARG DOWNLOAD_MODELS=ON
RUN cmake \
      -DBUILD_PYTHON=ON \
      # in case you run into 'file DOWNLOAD HASH mismatch' 'status: [7;"Couldn't connect to server"]' use 'docker build . --build-arg DOWNLOAD_MODELS=OFF'
      #-DDOWNLOAD_BODY_25_MODEL=$DOWNLOAD_MODELS -DDOWNLOAD_BODY_MPI_MODEL=$DOWNLOAD_MODELS -DDOWNLOAD_HAND_MODEL=$DOWNLOAD_MODELS -DDOWNLOAD_FACE_MODEL=$DOWNLOAD_MODELS \
      ..
# fix 'nvcc fatal: Unsupported gpu architecture'
#RUN sed -ie 's/set(AMPERE "80 86")/#&/g'  ../cmake/Cuda.cmake && \
#    sed -ie 's/set(AMPERE "80 86")/#&/g'  ../3rdparty/caffe/cmake/Cuda.cmake
# fix 'recipe for target 'caffe/src/openpose_lib-stamp/openpose_lib-configure' failed'
#RUN sed -i '5 i set(CUDA_cublas_device_LIBRARY "/usr/local/cuda-10.0/targets/x86_64-linux/lib/libcublas.so")' ../3rdparty/caffe/cmake/Cuda.cmake

RUN make -j$(nproc)
RUN make install
ENV PYTHONPATH "${PYTHONPATH}:/openpose/build/python/openpose"

# HF-NHMT_nsh
WORKDIR /tmp/
RUN apt-get install wget && \
    wget --quiet https://repo.anaconda.com/archive/Anaconda3-2022.05-Linux-x86_64.sh && \
    bash Anaconda3-2022.05-Linux-x86_64.sh -b -p /opt/conda

ENV PATH /opt/conda/bin:$PATH
WORKDIR /
RUN /bin/bash -c "git clone https://github.com/jzi040941/HF-NHMT.git && cd HF-NHMT && \ 
    conda init bash && \
    conda env create -f configs/conda_new.yml && \
    git submodule init && git submodule update"