# kernel-grsec-build - Kernel Build with GRSEC 

## Overview
This repository is dedicated to building various versions of the Linux kernel using the grsec patch. Our goal is to enhance the security of Linux distributions by applying the proven security enhancements provided by grsecurity. We utilize containers (Podman) to streamline and isolate the build process across multiple Linux distributions, including CentOS, Rocky Linux, Debian, and Ubuntu.

## Why grsecurity?
Grsecurity is a set of patches for the Linux kernel aimed at enhancing its security. It includes features designed to harden the system against a wide range of security threats, making it a valuable asset for any security-focused Linux user or administrator.

## Getting Started

### Prerequisites
- Podman installed on your system
- Basic understanding of containerization
- Some familiarity with Linux kernel compilation

### Setup
1. **Install Podman**: Follow the [official Podman installation guide](https://podman.io/getting-started/installation) for your distribution.
2. **Clone the Repository**: `git clone https://github.com/JLENF/kernel-grsec-build.git`
3. **Navigate to the Project**: `cd kernel-grsec-build`
4. **Important**: For the CentOS or Rocky Linux build, ensure you have the rpmbuild directory created; the RPM files will be placed inside this directory.
5. **.config file**. You can place your .config file inside the build directory to be used in the build.

### Building the Kernel
To build the kernel for a specific distribution, run the following command, replacing `<distro>` with your target distribution (e.g., `centos`, `rockylinux`, `debian`, `ubuntu`);
Choose a kernel version to build (`5.4`, `5.15`) in `<version>` and choose a tag to be inserted in the name of the generated file in `<tag>`
You need to provide your `username` and `password` for your grsecurity subscription (if you don't have one, please request at [grsecurity.net](https://grsecurity.net/purchase)):

```bash
podman container run -it --rm -v $PWD/scripts:/scripts -v $PWD/built_packages:/root/rpmbuild -e version=<version> -e username=YOURUSERNAME -e password=YOURPASSOWRD -e pkgname=<tag> <distro> /scripts/build.sh
```

Example for build latest kernel-5.15 for Rockylinux 8:

```bash
podman container run -it --rm -v $PWD/scripts:/scripts -v $PWD/built_packages:/root/rpmbuild -e version=5.15 -e username=YOURUSERNAME -e password=YOURPASSOWRD -e pkgname=el8 rockylinux:8 /scripts/build.sh
```

### Building a Docker image to speed up the process
If you are running many tests and don't want to wait for the standard installation of the necessary packages, you can create an image and use it during the build.
In the `Dockerfile/centos7` directory, there is an example for Centos7.
To build the image, use:

```bash
cd Dockerfile/centos7

podman build -t centos7-buid:v1 .
```

After build docker image, build kernel using this docker image with installed packages:

Example for build latest kernel-5.15 for Centos 7 using builded docker image:

```bash
podman container run -it --rm -v $PWD/scripts:/scripts -v $PWD/built_packages:/root/rpmbuild -e version=5.15 -e username=YOURUSERNAME -e password=YOURPASSOWRD -e pkgname=el7 localhost/centos7-build:v1 /scripts/build.sh
```

## Supported Distributions (tested)
| Distro       | Kernel 5.4  | Kernel 5.15 | Kernel 6.6 |
|--------------|-------------|-------------|-------------|
| CentOS 7     |     ✅     |     ✅     |             |
| Rockylinux 8 |     ✅     |     ✅     |             |
| Rockylinux 9 |             |     ✅     |             |
| Debian 10    |             |     ✅     |             |
| Debian 11    |             |     ✅     |             |
| Ubuntu 20.04 |             |     ✅     |             |


## Contributing
We welcome contributions from the community! Whether it's adding support for a new distribution, improving the build process, or fixing a bug, your contributions are invaluable to us.

To contribute, please:
1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Commit your changes with clear, descriptive messages.
4. Push your branch and submit a pull request.

## License
This project is licensed under the MIT License.

## Acknowledgments
- The grsecurity team for their continued efforts in enhancing Linux security

We hope this project serves your needs and contributes to the security of your Linux environments.
