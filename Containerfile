#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
ARG java_image_tag=17-jammy

FROM eclipse-temurin:${java_image_tag}
ARG hive_uri=https://downloads.apache.org
ARG spark_uid=185

RUN set -ex && \
    sed -i 's/http:\/\/deb.\(.*\)/https:\/\/deb.\1/g' /etc/apt/sources.list && \
    apt-get update && \
    ln -s /lib /lib64 && \
    apt install -y bash \
        coreutils \
        curl \
        krb5-user \
        libc6 \
        libpam-modules \
        libnss3 \
        net-tools \
        procps \
        tini && \
    mkdir -p /opt/spark && \
    #mkdir -p /opt/spark/examples && \
    mkdir -p /opt/spark/work-dir && \
    touch /opt/spark/RELEASE && \
    echo ${spark_version} > /opt/spark/RELEASE && \
    rm /bin/sh && \
    ln -sv /bin/bash /bin/sh && \
    useradd -u ${spark_uid} -m spark && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
    rm -rf /var/cache/apt/* && rm -rf /var/lib/apt/lists/*

COPY jars /opt/spark/jars
COPY RELEASE /opt/spark/RELEASE
COPY bin /opt/spark/bin
COPY sbin /opt/spark/sbin
COPY kubernetes/dockerfiles/spark/entrypoint.sh /opt/
COPY kubernetes/dockerfiles/spark/decom.sh /opt/
#COPY examples /opt/spark/examples
COPY kubernetes/tests /opt/spark/tests
COPY data /opt/spark/data

RUN curl ${hive_uri}/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz \
	| tar xvz -C /opt/ \
	&& ln -s /opt/apache-hive-3.1.3-bin /opt/hive

ENV SPARK_HOME /opt/spark

WORKDIR /opt/spark/work-dir
RUN chown spark:spark /opt/spark/work-dir && \
    chmod g+w /opt/spark/work-dir && \
    chmod a+x /opt/decom.sh

ENTRYPOINT [ "/opt/entrypoint.sh" ]

USER ${spark_uid}
