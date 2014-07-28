FROM centos:centos6
MAINTAINER Benjamin Tiefert <ben@tiefert.com>

## Utilities needed to perform the install
RUN yum -y install wget

## Java JDK
RUN yum -y install java-1.7.0-openjdk

## Latest version of Jenkins
RUN wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
RUN rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key
RUN yum -y install jenkins

## Stable Version of Jenkins
#RUN wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat-stable/jenkins.repo
#RUN rpm --import http://pkg.jenkins-ci.org/redhat-stable/jenkins-ci.org.key 
#RUN yum -y install jenkins

## Perforce Client
RUN wget -O /usr/local/bin/p4 ftp://ftp.perforce.com/perforce/r14.1/bin.linux26x86_64/p4
RUN chmod +x /usr/local/bin/p4

## Jenkins Perforce Plugin
## From https://github.com/jenkinsci/perforce-plugin
RUN mkdir -p /var/lib/jenkins/plugins
RUN wget -O /var/lib/jenkins/plugins/perforce.hpi http://mirrors.jenkins-ci.org/plugins/perforce/latest/perforce.hpi

EXPOSE 8080 8009

#CMD /etc/alternatives/java -Djava.awt.headless=true -DJENKINS_HOME=/var/lib/jenkins -jar /usr/lib/jenkins/jenkins.war --logfile=/var/log/jenkins/jenkins.log --webroot=/var/cache/jenkins/war --httpPort=8080 --ajp13Port=8009 --debug=5 --handlerCountMax=100 --handlerCountMaxIdle=20
CMD /etc/alternatives/java -DJENKINS_HOME=/var/lib/jenkins -jar /usr/lib/jenkins/jenkins.war --webroot=/var/cache/jenkins/war --httpPort=8080 --ajp13Port=8009 --debug=5 --handlerCountMax=100 --handlerCountMaxIdle=20
