#!/bin/bash
echo "Executing postStart script..."
apt-get install curl -y
cd /
ARCHITECTURE=$(arch)
if [ "$ARCHITECTURE" == "x86_64" ]; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
else
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
fi
chmod +x /kubectl
POD_NAME=$(/kubectl get pods -n testing | grep php-fpm | grep Running | awk '{print $1}')
if [ -z "$POD_NAME" ]; then
    echo "null"
else
    /kubectl cp $POD_NAME:/app/data/database.sqlite /app/data/database.sqlite -n testing
fi