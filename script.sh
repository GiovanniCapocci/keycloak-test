#!/bin/bash
set -e
# trap 'echo "Something went wrong ..."; [[ -d "$config_checkout_dir" ]] && echo "Removing $config_checkout_dir" && rm -rf "$config_checkout_dir"' ERR
app_user=dockertestusr
app_name=keycloak-test
containers_data_base_path=/srv/containers_data

config_checkout_dir=/tmp/$app_name
config_files_dir=$containers_data_base_path/$app_name/config-files
docker_files_dir=/home/$app_user/$app_name
storage_dir=$containers_data_base_path/$app_name/data
logs_dir=$containers_data_base_path/$app_name/logs
certificates_dir=$containers_data_base_path/$app_name/certificates

repo_url=https://github.com/GiovanniCapocci/keycloak-test.git

sudo -u $app_user rm -rf $config_checkout_dir

echo "git clone"
git clone $repo_url $config_checkout_dir
cd $config_checkout_dir

echo "Copying config files"
echo $config_files_dir
if [ -d $config_files_dir ]; then
    sudo -u $app_user rm -r $config_files_dir
fi
sudo -u $app_user -i mkdir -p $config_files_dir
sudo -u $app_user -i cp -r $config_checkout_dir/config-files/* $config_files_dir

echo "Copying docker files"
echo $docker_files_dir
if [ -d $docker_files_dir ]; then
    sudo -u $app_user rm -r $docker_files_dir
fi

sudo -u $app_user -i mkdir -p $docker_files_dir
sudo -u $app_user -i cp -r $config_checkout_dir/docker-files/* $docker_files_dir
sudo -u $app_user -i cp -r $config_checkout_dir/docker-files/.env $docker_files_dir

echo "Creating certificates"
echo $certificates_dir
if [ -d $certificates_dir ]; then
    sudo -u $app_user rm -r $certificates_dir
fi
sudo -u $app_user -i mkdir $certificates_dir
echo "Generating a new self-signed certificate for Keycloak"
sudo -u $app_user openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$certificates_dir/keycloak.key" \
    -out "$certificates_dir/keycloak.crt" \
    -days 825 \
    -subj "/CN=keycloak"
sudo -u $app_user chmod 644 "$certificates_dir/keycloak.key"
sudo -u $app_user chmod 644 "$certificates_dir/keycloak.crt"

echo "Generating a new self-signed certificate for nginx"
sudo -u $app_user openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$certificates_dir/nginx.key" \
    -out "$certificates_dir/nginx.crt" \
    -days 825 \
    -subj "/CN=keycloak.host.test.gr" \
    -addext "subjectAltName=DNS:keycloak.host.test.gr"
sudo -u $app_user chmod 644 "$certificates_dir/nginx.key"
sudo -u $app_user chmod 644 "$certificates_dir/nginx.crt"

folders_to_create=(
    $storage_dir
    $storage_dir/postgresql_db_keycloak/data
    $logs_dir
    $logs_dir/keycloak
    $logs_dir/proxy
)
echo "Creating storage, log and keystore folders if not exist"
for path in "${folders_to_create[@]}"
do
    if [ ! -d $path ]; then
        echo $path
        sudo -u $app_user -i mkdir -p $path
    fi
done

cd $docker_files_dir
docker compose pull
docker compose down
docker compose up -d

git credential-cache exit
sudo rm -rf $config_checkout_dir