#!/bin/bash
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

if [ -f "docker-compose.yml" ]; then
    echo "docker-compose.yml already exists. Please run this script in an empty directory"
    exit 1
fi

if [ -f ".env" ]; then
    echo ".env already exists. Please run this script in an empty directory"
    exit 1
fi

echo "This script will install the novauniverse tournament system"
echo "This will also install some dependencies like: pwgen and docker"
echo "To continue press enter"
read

if ! command -v pwgen &> /dev/null
then
    echo "pwgen not found, installing..."
    apt update && apt install -y pwgen
    echo "pwgen installed successfully"
else
    echo "pwgen is already installed"
fi

if ! command -v docker &> /dev/null
then
    echo "Docker not found, installing..."
    apt update && apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update && apt install -y docker-ce docker-ce-cli containerd.io
    echo "Docker installed successfully"
else
    echo "Docker is already installed"
fi

echo "Please enter the credentials provided by the novauniverse staff for our private docker registry"
if ! docker login registry1.novauniverse.net; then
    echo "Login failed, stopping script."
    exit 1
fi

echo "Login successful, continuing script..."
echo "Please enter the name of the tournament to install from the list below. Note that the names are case sensitive"
curl "https://novauniverse.s3.amazonaws.com/tournamentsystem/versions.json"
echo ""
echo -n "Enter valid branch: "
read branch
echo "Trying to download from branch $branch"

echo "Downloading from https://novauniverse.s3.amazonaws.com/tournamentsystem/prod/$branch/docker-compose.yml"
curl --silent --show-error --fail "https://novauniverse.s3.amazonaws.com/tournamentsystem/prod/$branch/docker-compose.yml" -o docker-compose.yml
if [ $? -eq 0 ]; then
    echo "Docker compose downloaded"
else
    rm docker-compose.yml
    echo "Failed to find docker-compose.yml for $branch."
    exit 1
fi

echo "Setting up .env file"
touch .env
echo "DATA_DIRECTORY=\"$(pwd)/data\"" >> .env
echo "DB_PASSWORD=\"$(pwgen -s -1 32)\"" >> .env
echo "DB_DATABASE=\"minecraft_tournament\"" >> .env
echo "WS_API_SERVER_KEY=\"$(cat /proc/sys/kernel/random/uuid)\"" >> .env
echo "WS_API_CLIENT_KEY=\"$(cat /proc/sys/kernel/random/uuid)\"" >> .env
echo "OFFLINE_MODE=\"false\"" >> .env
echo ".env file created"

echo "Pulling images"
docker compose pull
echo "Starting containers"
docker compose up -d
echo "Attaching to logs"
docker compose logs -f