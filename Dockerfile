# frontend config
ARG NEXT_PUBLIC_API_PATH=/
ARG NEXT_PUBLIC_USE_PROXY=true
ARG NEXT_PUBLIC_SITE_URL=/

FROM ubuntu:24.04 AS frontend-builder
ARG NEXT_PUBLIC_API_PATH
ARG NEXT_PUBLIC_USE_PROXY
ARG NEXT_PUBLIC_SITE_URL
SHELL ["/bin/bash", "-c"]

WORKDIR /opt
COPY beaconplusWeb/ beaconplusWeb/
WORKDIR /opt/beaconplusWeb

RUN <<EOF 
apt-get update
apt-get install -y curl
# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"
# Download and install Node.js:
nvm install 22
npm install
echo "NEXT_PUBLIC_API_PATH=${NEXT_PUBLIC_API_PATH}" > env/production
echo "NEXT_PUBLIC_USE_PROXY=${NEXT_PUBLIC_USE_PROXY}" >> env/production
echo "NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL}" >> env/production
npm run update
EOF


FROM python:3.12-slim-bullseye AS bycon

WORKDIR /opt/bycon
COPY . .
SHELL ["/bin/bash", "-c"]

RUN <<EOF 
    apt-get update 
    apt-get install -y build-essential zlib1g-dev rsync apache2
    # build bycon
    pip install build requests
    pip install -r requirements.txt
    mkdir -p /var/www/cgi-bin/bycon /var/www/cgi-bin/beaconplus /var/www/Documents/tmp /var/www/Documents/Sites/beaconplus
    pip3 uninstall bycon --break-system-packages 
    rm -rf ./dist
    python3 -m build --sdist .
    BY=(./dist/*tar.gz)
    pip3 install $BY --break-system-packages
    ./install.py --no-sudo
    rm -rf ./build
    rm -rf ./dist
    rm -rf ./bycon.egg-info
    # enable bycon webservice
    cp config/apache-webserver/001-beacon.conf /etc/apache2/sites-available/
    a2dissite 000-default
    a2ensite 001-beacon
EOF

COPY --from=frontend-builder /opt/beaconplusWeb/out /var/www/Documents/Sites/beaconplus

WORKDIR /

# cleaning up
RUN <<EOF
    rm -rf /opt
    pip cache purge
    apt-get remove -y build-essential zlib1g-dev rsync
    apt-get autoremove -y
EOF

EXPOSE 80
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
