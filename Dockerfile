# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"; you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

FROM centos:7

LABEL maintainer="mathieu.poudret@f2i-consulting.com"

ENV CFLAGS="-fPIC -O2"
ENV CXXFLAGS="-fPIC -O2"

# RUN lance les commandes
RUN	yum install -y \
	# minizip is a dependence of fesapi \ 
	minizip-devel \ 	
	# git is used to clone fesapi repository from GitHub \	
	git \				
	# C and C++ compilers
	gcc-c++ \		
	# make is used to process Unix Makefiles
	make \				
	# libuuid is a dependence of fesapi
	libuuid-devel \
	# wget is used to download ressources. We use it instead of ADD in order to
	# minimize the size of the docker image by limitating the number of layers
	wget &&\
yum clean all && \
\
# epel repository is used to get both boost169 and cmake3 packages
wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
rpm -ivh epel-release-latest-7.noarch.rpm && \
rm -f epel-release-latest-7.noarch.rpm && \
yum --enablerepo=epel install -y \
	# cmake3 is used to automatize building configuration
	cmake3 \
	# boost is a dependence of both avro and fesapi etp
	boost169-static && \
\
##############
# hdf5 install
# hdf5 is a dependence of fesapi
mkdir fesapiEnv && \
cd fesapiEnv && \
mkdir dependencies && \
cd dependencies && \
wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.5/src/hdf5-1.10.5.tar.gz && \
tar xf hdf5-1.10.5.tar.gz && \
cd hdf5-1.10.5 && \
mkdir build && \
cd build && \
cmake3 -G "Unix Makefiles" \
	-DCMAKE_BUILD_TYPE:STRING=Release \
	-DBUILD_SHARED_LIBS:BOOL=OFF \
	-DBUILD_TESTING:BOOL=OFF \
	-DHDF5_BUILD_TOOLS:BOOL=OFF \
	-DHDF5_BUILD_EXAMPLES:BOOL=OFF \
	-DHDF5_BUILD_CPP_LIB:BOOL=OFF \
	-DHDF5_BUILD_HL_LIB:BOOL=OFF \
	-DCMAKE_INSTALL_PREFIX:STRING=/fesapiEnv/dependencies/hdf5-1.10.5/hdf5 \
	.. && \
cmake3 --build . --config Release && \	
make install && \
\
##############
# avro install
# avro is a dependence of fesapi etp
cd ../.. && \
wget https://apache.mirrors.benatherton.com/avro/stable/cpp/avro-cpp-1.9.1.tar.gz && \
tar xf avro-cpp-1.9.1.tar.gz && \
cd avro-cpp-1.9.1 && \
mkdir build && \
cd build && \
cmake3 -G "Unix Makefiles" -DBOOST_INCLUDEDIR=/usr/include/boost169/ -DBOOST_LIBRARYDIR=/usr/lib64/boost169 .. && \
make install && \
\
################
# fesapi install
cd ../../.. && \
git clone https://github.com/F2I-Consulting/fesapi.git && \
cd fesapi && \
git checkout etp && \
cd ..  && \
mkdir build && \
cd build && \
cmake3 \
 	-DHDF5_C_INCLUDE_DIR=/fesapiEnv/dependencies/hdf5-1.10.5/hdf5/include \
	-DHDF5_C_LIBRARY_RELEASE=/fesapiEnv/dependencies/hdf5-1.10.5/hdf5/lib/libhdf5.a \
	-DMINIZIP_INCLUDE_DIR=/usr/include/minizip \
	-DMINIZIP_LIBRARY_RELEASE=/usr/lib64/libminizip.so \
 	-DZLIB_INCLUDE_DIR=/usr/include \
 	-DZLIB_LIBRARY_RELEASE=/usr/lib64/libz.so \
 	-DUUID_INCLUDE_DIR=/usr/include \
 	-DUUID_LIBRARY_RELEASE=/lib64/libuuid.so.1 \
	-DWITH_ETP=ON \
	-DWITH_EXAMPLE=TRUE \
	-DBOOST_INCLUDEDIR=/usr/include/boost169 \
	-DBOOST_LIBRARYDIR=/usr/lib64/boost169 \
	-DAVRO_INCLUDE_DIR=/usr/local/include/avro \
	-DAVRO_LIBRARY_RELEASE=/usr/local/lib/libavrocpp_s.a \
	-DWITH_EXPERIMENTAL=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	-DBoost_USE_STATIC_LIBS=ON \
	-DBoost_USE_DEBUG_LIBS=OFF \
	-DBoost_USE_RELEASE_LIBS=ON \
	-DBoost_USE_MULTITHREADED=ON \
	-DBoost_USE_STATIC_RUNTIME=OFF \
	-DHDF5_1_10=ON \
	../fesapi && \
make VERBOSE=OFF && \
make install && \ 
\
##########
# cleaning 
cd .. && \
rm -rf fesapi && \
rm -rf dependencies && \
cd build && \
mv install .. && \
rm -rf * && \
mv ../install/ . && \
yum install -y yum-plugin-remove-with-leaves && \
yum remove -y \
	cmake3 \
	boost169-static \
	minizip-devel \
	git \
	gcc-c++ \
	make \
	libuuid-devel \
	wget \
	--remove-leaves && \
yum remove -y yum-plugin-remove-with-leaves && \
yum install -y \
	minizip \
	libuuid && \
yum clean all

# generate .epc and .h5 files
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/fesapiEnv/build/install/lib64/:/usr/local/lib/
WORKDIR fesapiEnv/build/install
RUN ./example

# note from https://docs.docker.com/engine/reference/builder/ 
# The EXPOSE instruction informs Docker that the container listens on the specified 
# network ports at runtime. You can specify whether the port listens on TCP or UDP, 
# and the default is TCP if the protocol is not specified.
# The EXPOSE instruction does not actually publish the port. It functions as a type
# of documentation between the person who builds the image and the person who runs
# the container, about which ports are intended to be published. To actually publish
# the port when running the container, use the -p flag on docker run to publish and 
# map one or more ports, or the -P flag to publish all exposed ports and map them to
# high-order ports.
#
# in order to run the container on your docker desktop use, please use:
# docker run -p 8080:8080 [IMAGE]
EXPOSE 8080

# setting command to launch at runtime
CMD ["./etpServerExample", "0.0.0.0", "8080", "../../testingPackageCpp.epc"]
