FROM centos:7

RUN yum update -y
RUN yum install -y vim wget dnf lftp yum-plugin-changelog
RUN dnf install -y gcc-plugin-devel ncurses-devel openssl-devel elfutils-libelf-devel hmaccalc zlib-devel binutils-devel
RUN yum groupinstall -y "Development Tools"
RUN yum install -y centos-release-scl
RUN yum install -y devtoolset-7 devtoolset-7-gcc-plugin-devel python-docutils
