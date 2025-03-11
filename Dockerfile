FROM ubuntu:latest
RUN apt update && apt install -y software-properties-common
RUN add-apt-repository ppa:bartbes/love-stable
RUN apt update && apt install -y love
ENV XDG_RUNTIME_DIR=/run/user/
COPY allocator.love .
EXPOSE 6790
CMD ["love", "allocator.love"]