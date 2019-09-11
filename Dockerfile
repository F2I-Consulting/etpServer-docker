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

# RUN lance les commandes
# yum equiv apt-get
RUN yum update -y \
	&& yum install -y \
	minizip-devel \
	automake \
	pcre-devel \
	git \
	gcc-c++ \
	make \
	byacc \
	libuuid-devel \
	wget

RUN bash
	
# boost install
RUN wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RUN rpm -ivh epel-release-latest-7.noarch.rpm
RUN yum --enablerepo=epel update -y \
	&& yum --enablerepo=epel install -y \
	cmake3 \
	hdf5-devel \
	boost169-devel

# AVRO install
WORKDIR /fesapiEnv/dependencies
ADD https://apache.mirrors.benatherton.com/avro/stable/cpp/avro-cpp-1.9.1.tar.gz .
RUN tar xf avro-cpp-1.9.1.tar.gz
WORKDIR avro-cpp-1.9.1
WORKDIR build
RUN cmake3 -G "Unix Makefiles" -DBOOST_INCLUDEDIR=/usr/include/boost169/ -DBOOST_LIBRARYDIR=/usr/lib64/boost169 ..   
RUN make install

# Fesapi install
WORKDIR ../../..
RUN git clone https://github.com/F2I-Consulting/fesapi.git
WORKDIR fesapi
RUN git checkout etp
WORKDIR ../build
RUN cmake3 \
 	-DHDF5_C_INCLUDE_DIR=/usr/include \
 	-DHDF5_C_LIBRARY_RELEASE=/usr/lib64/libhdf5.so \
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
 	-DAVRO_LIBRARY_RELEASE=/usr/local/lib/libavrocpp.so \
	-DWITH_EXPERIMENTAL=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	../fesapi
	RUN make VERBOSE=OFF
# -j$(nproc)
RUN make install 
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/fesapiEnv/build/install/lib64/:/usr/local/lib/

# generate .epc and .h5 files
WORKDIR install
RUN ./example

# make port 8080 available to the world outside this container
EXPOSE 8080

CMD ["./etpServerExample", "0.0.0.0", "8080", "../../testingPackageCpp.epc"]