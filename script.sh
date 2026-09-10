#!/bin/bash
set -e
trap 'echo "Something went wrong ..."; [[ -d "$config_checkout_dir" ]] && echo "Removing $config_checkout_dir" && rm -rf "$config_checkout_dir"' ERR
read username
app_user=dockertestusr
app_name=keycloak-test
containers_data_base_path=/srv/containers_data

config_checkout_dir=/tmp/$app_name
config_files_dir=$containers_data_base_path/$app_name/config-files
docker_files_dir=/home/$app_user/$app_name
storage_dir=$containers_data_base_path/$app_name/data
logs_dir=$containers_data_base_path/$app_name/logs
certificates_dir=$containers_data_base_path/$app_name/certificates
secrets_dir=/home/$app_user/secrets

repo_url=https://github.com/GiovanniCapocci/keycloak-test.git

sudo -u $app_user rm -rf $config_checkout_dir

echo "git clone"
git clone $repo_url $config_checkout_dir
cd $config_checkout_dir


function apply_secrets() {
    echo using $1 targeting $2
    grep -v '^#' "$1" | while IFS=: read -r f1 f2
    do
        if [ -n "$f1" ]; then
            sed -i "s:$f1:$f2:g" $2
        fi
    done
}

apply_secrets $secrets_dir/env.secrets $config_checkout_dir/docker-files/.env
perl -p -i -e "s/\r//g" $config_checkout_dir/docker-files/.env

if grep -q '{{.*}}' "$2"; then
    echo "ERROR: unresolved placeholder(s) left in $2" >&2
    grep -n '{{.*}}' "$2"
    exit 1
fi

echo "Copying config files"
echo $config_files_dir
if [ -d $config_files_dir ]; then
    sudo -u $app_user -i rm -r $config_files_dir
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

echo "Creating certificates directory"
echo $certificates_dir
if [ -d $certificates_dir ]; then
    sudo -u $app_user rm -r $certificates_dir
fi
sudo -u $app_user -i mkdir $certificates_dir

echo "Copying certificates"
sudo -u $app_user -i cp -r $secrets_dir/nginx.* $certificates_dir
sudo -u $app_user -i cp -r $secrets_dir/keycloak.* $certificates_dir

sudo -u $app_user chmod 644 "$certificates_dir/nginx.crt" "$certificates_dir/keycloak.crt"
sudo -u $app_user chmod 644 "$certificates_dir/nginx.key" "$certificates_dir/keycloak.key"

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

docker login ghcr.io -u $username
cd $docker_files_dir
docker compose pull
docker compose down
docker compose up -d
docker logout ghcr.io

git credential-cache exit
sudo rm -rf $config_checkout_dir
exit