FROM    ubuntu:18.04

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    rm -rf /var/lib/apt/lists/*
RUN add-apt-repository universe

# Install primary dependencies
RUN sed 's/main$/main universe/' -i /etc/apt/sources.list && \
	apt-get clean && apt-get update && \
  apt-get install -y locales && \
  locale-gen en_US.UTF-8 && \
  apt-get install -y software-properties-common unzip git lftp sudo zip curl wget && \
	sudo apt install -y openjdk-8-jdk && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk8-installer && \
	echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
	rm -rf /tmp/*

# Set the locale
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 
RUN update-locale LANG=en_US.UTF-8 LC_MESSAGES=POSIX

# Fix certificate issues, found as of 
# https://bugs.launchpad.net/ubuntu/+source/ca-certificates-java/+bug/983302
RUN apt-get install -y ca-certificates-java && \
	apt-get clean && \
	update-ca-certificates -f && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /var/cache/oracle-jdk8-installer;

# Making the right java available
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

# Configs directories and users for pentaho 
RUN mkdir /pentaho && \
  mkdir /home/pentaho && \
  mkdir /home/pentaho/.kettle && \
  mkdir /home/pentaho/.aws && \
  groupadd -r pentaho && \
  useradd -r -g pentaho -p $(perl -e'print crypt("pentaho", "aa")' ) -G sudo pentaho && \ 
  chown -R pentaho.pentaho /pentaho && \ 
  chown -R pentaho.pentaho /home/pentaho

WORKDIR /pentaho
USER pentaho
# ARG PENTAHO_DOWNLOAD_URL=https://netcologne.dl.sourceforge.net/project/pentaho/Pentaho%208.3/client-tools/pdi-ce-8.3.0.0-371.zip
ARG PENTAHO_DOWNLOAD_URL=https://sourceforge.net/projects/pentaho/files/Pentaho%208.2/client-tools/pdi-ce-8.2.0.0-342.zip/download

# Downloads pentaho
RUN wget -q -O kettle.zip ${PENTAHO_DOWNLOAD_URL} && \
  unzip -qq kettle.zip && \
  rm -rf kettle.zip

# downloads google sdk
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \ 
sudo apt-get install -y apt-transport-https ca-certificates gnupg && \
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
sudo apt-get update && sudo apt-get install -y google-cloud-sdk

RUN sudo apt-get update && \
    sudo apt-get install -y \
        python3-pip \
        python3-setuptools \
        groff \
        less \
    && pip3 install --upgrade pip \
    && sudo apt-get clean

WORKDIR /pentaho/data-integration

COPY mec-test-310713-0b0bc8a3e223.json /pentaho/data-integration/credentials.json
ENV GOOGLE_APPLICATION_CREDENTIALS /pentaho/data-integration/credentials.json

# Adds connections config files
ADD --chown=pentaho:pentaho scripts/* ./

# Changes spoon.sh to expose memory to env-vars
RUN sed -i \
  's/-Xmx[0-9]\+m/-Xmx\$\{_RUN_XMX:-2048\}m/g' spoon.sh 

ENV PDI_HOME /pentaho/data-integration

COPY test/etl/* /pentaho/project/

ENTRYPOINT ["/pentaho/data-integration/run.sh"]
