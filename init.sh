#!/bin/bash

# Install Amazon Corretto 17
# https://docs.aws.amazon.com/corretto/latest/corretto-17-ug/amazon-linux-install.html

sudo yum install -y java-17-amazon-corretto-headless

# Download and run minecraft server
# https://www.minecraft.net/en-us/download/server

wget https://piston-data.mojang.com/v1/objects/84194a2f286ef7c14ed7ce0090dba59902951553/server.jar

# Accept EULA
echo "eula=true" >> eula.txt

java -Xmx1024M -Xms1024M -jar server.jar nogui
