#!/bin/bash

# Install Docker

sudo yum update -y
sudo yum install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

#R un the container on the port 8080 daemonized

docker run -d -p 8080:9000 ghcr.io/podtato-head/podtatoserver:v0.1.2

#Get your Public IP Address of AWS Instance
export PUBLIC_IPV4_ADDRESS="$(curl http://169.254.169.254/latest/meta-data/public-ipv4)"


# Strings for github- attention: has to set up manually on github
clear

cat << EOF


=======
Application name: 
-- podtatohead-on-aws

Homepage URL:     
- https://$PUBLIC_IPV4_ADDRESS.nip.io

Authorization callback URL: 
- https://$PUBLIC_IPV4_ADDRESS.nip.io/oauth2/callback
=======


EOF

# wait for key

echo "Bitte Daten aus Anzeige manuell nach GitHub übertragen, danach Bitte Taste drücken"
read -sn1


# Install and configure LetsEncrypt

sudo amazon-linux-extras install epel -y
sudo yum-config-manager --enable epel

sudo yum install certbot -y

export PUBLIC_IPV4_ADDRESS="$(curl http://169.254.169.254/latest/meta-data/public-ipv4)"
export PUBLIC_INSTANCE_NAME="$(curl http://169.254.169.254/latest/meta-data/public-hostname)"

sudo certbot certonly --standalone --preferred-challenges http -d $PUBLIC_IPV4_ADDRESS.nip.io --staging

# Run and configure oauth2-proxy
#  Download oauth2-proxy
mkdir -p /tmp/oauth2-proxy
sudo mkdir -p /opt/oauth2-proxy

cd /tmp/oauth2-proxy
curl -sfL https://github.com/oauth2-proxy/oauth2-proxy/releases/download/v7.1.3/oauth2-proxy-v7.1.3.linux-amd64.tar.gz | tar -xzvf -

sudo mv oauth2-proxy-v7.1.3.linux-amd64/oauth2-proxy /opt/oauth2-proxy/

#  Create cookie secret

export COOKIE_SECRET=$(python -c 'import os,base64;
print(base64.urlsafe_b64encode(os.urandom(16)).decode())') 
 
#  Set some variables (could also be a script)

#clear screen and define password in envvar
clear
printf "Bitte Passwort zum entschlüsseln und setzen der Secrets eingeben: "
read PASSWORD

# decrypt and define git hub credentials 
export GITHUB_USER="$(echo $ENC_GITHUB_USER | openssl enc -d -aes-256-cbc -md sha512 -a -salt -pass pass:$PASSWORD)"                    # Parameter nach -a "-pbkdf2 -iter 100000" funktionieren nur manchmal daher entfernt
export GITHUB_CLIENT_ID="$(echo $ENC_GITHUB_CLIENT_ID | openssl enc -d -aes-256-cbc -md sha512 -a -salt -pass pass:$PASSWORD)"          # Parameter nach -a "-pbkdf2 -iter 100000" funktionieren nur manchmal daher entfernt
export GITHUB_CLIENT_SECRET="$(echo $ENC_GITHUB_CLIENT_SECRET | openssl enc -d -aes-256-cbc -md sha512 -a -salt -pass pass:$PASSWORD)"  # Parameter nach -a "-pbkdf2 -iter 100000" funktionieren nur manchmal daher entfernt
export PUBLIC_URL=$(curl http://169.254.169.254/latest/meta-data/public-ipv4).nip.io

#delete envvar 
unset PASSWORD

# Run oauth2-proxy

sudo /opt/oauth2-proxy/oauth2-proxy --github-user="${GITHUB_USER}"  --cookie-secret="${COOKIE_SECRET}" --client-id="${GITHUB_CLIENT_ID}" --client-secret="${GITHUB_CLIENT_SECRET}" --email-domain="*" --upstream=http://127.0.0.1:8080 --provider github --cookie-secure false --redirect-url=https://${PUBLIC_URL}/oauth2/callback --https-address=":443" --force-https --tls-cert-file=/etc/letsencrypt/live/$PUBLIC_URL/fullchain.pem --tls-key-file=/etc/letsencrypt/live/$PUBLIC_URL/privkey.pem

