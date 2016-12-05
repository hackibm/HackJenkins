FROM openjdk:8-jdk-alpine

RUN apk add --no-cache git openssh-client curl unzip bash ttf-dejavu coreutils

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container, 
# ensure you use the same uid
RUN addgroup -g ${gid} ${group} \
    && adduser -h "$JENKINS_HOME" -u ${uid} -G ${group} -s /bin/bash -D ${user}

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_VERSION 0.9.0
ENV TINI_SHA fa23d1e20732501c3bb8eeeca423c89ac80ed452

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.19.3}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=e97670636394092af40cc626f8e07b092105c07b

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins.io
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

#************************* NODE INSTALATION *********



ENV VERSION=v7.2.0 NPM_VERSION=3

#Instalcja node.js z npm
RUN apk add --no-cache make gcc g++ python linux-headers paxctl libgcc libstdc++ gnupg && \
	curl -o node-${VERSION}.tar.gz -sSL https://nodejs.org/dist/${VERSION}/node-${VERSION}.tar.gz && \
	tar -zxf node-${VERSION}.tar.gz && \
	cd node-${VERSION} && \
	export GYP_DEFINES="linux_use_gold_flags=0" && \
	 ./configure --prefix=/usr ${CONFIG_FLAGS}
	 
RUN	 cd node-${VERSION} && \
	 make -C out mksnapshot BUILDTYPE=Release && \
	 paxctl -cm out/Release/mksnapshot && \
	 make && \
	 make install && \
	 paxctl -cm /usr/bin/node && \
	 cd / && \
	 npm install -g npm@${NPM_VERSION}
	 
	 #find /usr/lib/node_modules/npm -name test -o -name .bin -type d | xargs rm -rf;
#	 apk del curl make gcc g++ python linux-headers paxctl gnupg ${DEL_PKGS} && \
	 #rm -rf  /node-${VERSION}.tar.gz /node-${VERSION} ${RM_DIRS} \
	  #    /tmp/* /var/cache/apk/* /root/.npm /root/.node-gyp /root/.gnupg \
	 #    /usr/lib/node_modules/npm/man /usr/lib/node_modules/npm/doc /usr/lib/node_modules/npm/html



#************************* NODE INSTALATION END *********

#************************* GRADLE INSTALATION *********



#************************* GRADLE INSTALATION END *********
ENV GRADLE_VERSION 3.2.1
ENV GRADLE_HOME /usr/lib/gradle/gradle-${GRADLE_VERSION}
ENV PATH ${PATH}:${GRADLE_HOME}/bin
RUN  mkdir -p /usr/lib/gradle && \
	 cd /usr/lib/gradle && \
	 curl -o gradle-${GRADLE_VERSION}-bin.zip -sSL https://downloads.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip && \
	 unzip gradle-${GRADLE_VERSION}-bin.zip && \
	 rm -f gradle-${GRADLE_VERSION}-bin.zip
	 

#************************* JENKINS INSTALATION PART #2 *********

USER ${user}

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

	 # from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh
