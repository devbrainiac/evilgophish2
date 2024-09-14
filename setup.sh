#!/usr/bin/env bash

# make our output look nice...
script_name="evilgophish setup"

function print_good () {
    echo -e "[${script_name}] \x1B[01;32m[+]\x1B[0m $1"
}

function print_error () {
    echo -e "[${script_name}] \x1B[01;31m[-]\x1B[0m $1"
}

function print_warning () {
    echo -e "[${script_name}] \x1B[01;33m[-]\x1B[0m $1"
}

function print_info () {
    echo -e "[${script_name}] \x1B[01;34m[*]\x1B[0m $1"
}

# Set variables from parameters
export HOME=/root
export GOCACHE=$HOME/.cache

# Install needed dependencies
function install_depends () {
    print_info "Installing dependencies with apt"
    apt-get update
    apt-get install build-essential letsencrypt certbot wget git net-tools tmux openssl jq -y
    print_good "Installed dependencies with apt!"
    print_info "Installing Go from source"

    curl -OL https://golang.org/dl/go1.19.linux-amd64.tar.gz

    if [ -d "/usr/local/go" ]; then
        rm -rf /usr/local/go
    fi

    tar -zxvf go1.19.linux-amd64.tar.gz -C /usr/local/

    if ! grep -q 'export PATH=$PATH:/usr/local/go/bin' /root/.profile ; then
        echo "export PATH=\$PATH:/usr/local/go/bin" >> /root/.profile
    fi

    # Add Go to the PATH environment variable for current script
    export PATH=$PATH:/usr/local/go/bin

    rm go1.19.linux-amd64.tar.gz

    print_good "Installed Go from source!"
}

# Configure and install evilginx3
function setup_evilginx3 () {
    # Prepare DNS for evilginx3
    sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
    sudo systemctl restart systemd-resolved

    print_info "Removing evilginx indicator (X-Evilginx header)..."
    sed -i 's/req.Header.Set(p.getHomeDir(), o_host)/\/\/req.Header.Set(p.getHomeDir(), o_host)/' evilginx2/core/http_proxy.go

    # Build evilginx3
    cd evilginx2 || exit 1
    make
    sudo make install

    print_info "Setting permissions to allow evilginx to bind to privileged ports..."
    sudo setcap CAP_NET_BIND_SERVICE=+eip evilginx

    cp ./build/evilginx /usr/local/bin

    mkdir -p ~/.evilginx/phishlets
    mkdir -p ~/.evilginx/redirectors
    cp ./phishlets/* ~/.evilginx/phishlets/
    cp ./redirectors/* ~/.evilginx/redirectors/
    wget -O /root/.evilginx/blacklist.txt https://github.com/aalex954/MSFT-IP-Tracker/releases/latest/download/msft_asn_ip_ranges.txt

    cd ..
    print_good "Configured evilginx3!"
}

# Configure and install gophish
function setup_gophish () {

    print_info "Configuring gophish"
    
    cd gophish || exit 1

    # Stripping X-Gophish 
    find . -type f -exec sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request_test.go
    find . -type f -exec sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog.go
    find . -type f -exec sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog_test.go
    find . -type f -exec sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request.go

    # Stripping X-Gophish-Signature
    find . -type f -exec sed -i 's/X-Gophish-Signature/X-Signature/g' webhook/webhook.go

    # Changing server name
    find . -type f -exec sed -i 's/const ServerName = "gophish"/const ServerName = "IGNORE"/' config/config.go

    # Changing rid value
    find . -type f -exec sed -i 's/const RecipientParameter = "rid"/const RecipientParameter = "keyname"/g' models/campaign.go

    # Replace rid with user input
    find . -type f -exec sed -i "s|client_id|keyname|g" {} \;
    find . -type f -exec sed -i "s|rid|keyname|g" {} \;

    go build
    cd ..
    print_good "Configured gophish!"
}

function main () {
    install_depends
    setup_gophish
    setup_evilginx3
    print_good "Installation complete!"
    print_info "It is recommended to run all servers inside a tmux session to avoid losing them over SSH!"
}

main
