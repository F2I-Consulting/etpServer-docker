# etpServer-docker
A basic ETP server using fesapi which serves the fesapi epc example. \
in order to run the container on your docker desktop, please publish the 8080 port using the command : docker run -p 8080:8080 [IMAGE]

A CLI client is also included in this container.\
Launch it using the command "docker run -it f2iconsulting/etpserver ./etpClientExample [SERVER_IP] [port]"
Just hit enter in the CLI in order to get a list of the available commands.
