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

ENV CFLAGS="-DNOCRYPT -fPIC -O2"
ENV CXXFLAGS="-DNOCRYPT -fPIC -O2"

# RUN lance les commandes
RUN	yum install -y \
	minizip-devel \
	automake \
	pcre-devel \
	git \
	gcc-c++ \
	make \
	byacc \
	libuuid-devel \
	wget &&\
	bash && \
yum clean all && \
\
# boost install
wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
rpm -ivh epel-release-latest-7.noarch.rpm && \
rm -f epel-release-latest-7.noarch.rpm && \
yum --enablerepo=epel install -y \
	cmake3 \
	boost169-static && \
\
# hdf5 install
mkdir fesapiEnv && \
cd fesapiEnv && \
mkdir dependencies && \
cd dependencies && \
wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.21/src/hdf5-1.8.21.tar.gz && \
tar xf hdf5-1.8.21.tar.gz && \
cd hdf5-1.8.21 && \
./configure --enable-static=yes --enable-shared=false --with-zlib=/usr/include,/usr/lib64/libz.so && \
make VERBOSE=ON -j$(nproc) && \
make install && \
\
# AVRO install
cd .. && \
wget https://apache.mirrors.benatherton.com/avro/stable/cpp/avro-cpp-1.9.1.tar.gz && \
tar xf avro-cpp-1.9.1.tar.gz && \
cd avro-cpp-1.9.1 && \
mkdir build && \
cd build && \
cmake3 -G "Unix Makefiles" -DBOOST_INCLUDEDIR=/usr/include/boost169/ -DBOOST_LIBRARYDIR=/usr/lib64/boost169 .. && \
make install && \
\
# Fesapi install
cd ../../.. && \
git clone https://github.com/F2I-Consulting/fesapi.git && \
cd fesapi && \
git checkout etp && \
cd ..  && \
mkdir build && \
cd build && \
cmake3 \
 	-DHDF5_C_INCLUDE_DIR=/fesapiEnv/dependencies/hdf5-1.8.21/hdf5/include \
	-DHDF5_C_LIBRARY_RELEASE=/fesapiEnv/dependencies/hdf5-1.8.21/hdf5/lib/libhdf5.a \
	-DMINIZIP_INCLUDE_DIR=/usr/include/minizip \
	-DMINIZIP_LIBRARY_RELEASE=/usr/lib64/libminizip.so \
 	-DZLIB_INCLUDE_DIR=/usr/include \
 	-DZLIB_LIBRARY_RELEASE=/usr/lib64/libz.so \
 	-DUUID_INCLUDE_DIR=/usr/include \
 	-DUUID_LIBRARY_RELEASE=/lib64/libuuid.so.1 \
	-DWITH_ETP=ON \
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
	../fesapi && \
make VERBOSE=OFF && \
make install && \ 
\
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
	automake \
	pcre-devel \
	git \
	gcc-c++ \
	make \
	byacc \
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

# make port 8080 available to the world outside this container
EXPOSE 8080

# setting command to launch at runtime
CMD ["./etpServerExample", "0.0.0.0", "8080", "../../testingPackageCpp.epc"]