#!sh

NAME_DOCKER_NETWORK=wp-net
VERSION_MYSQL=5.7
NAME_MYSQL_CONTAINER=mysql
ID_MYSQL_CONTAINER=''
PORT_LOCAL_MYSQL=3600

MYSQL_WP_DATABASE='wordpress'
MYSQL_WP_NAME='wordpress'
MYSQL_WP_PW=''

NAME_SQL_FILE=wordpress.sql
PATH_TO_DOCKER_LAP=docker-lap
NAME_DOCKER_LAP=lap
VERSION_DOCKER_LAP=0.1

VERSION_WORDPRESS=6.3

DIR_WP_APP=/opt/wordpress
DIR_HTTPS_KEYS=/var/www/keys

DOMAIN=''

function run_to_success() {
    while [ 1 ]
    do
        $*
        if [ $? -eq 0 ]
        then
            break
        fi
        sleep 3
    done
}

function create_docker_network() {
    docker network create --driver bridge --subnet 10.0.12.0/24 --gateway 10.0.12.1 $NAME_DOCKER_NETWORK
}

function gen_mysql_pw() {
    cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 16;echo
}

function deploy_mysql() {
    # init mysql database
    mysql_root_pw=$(gen_mysql_pw)
    echo $mysql_root_pw > mysql_root_password
    docker pull mysql:${VERSION_MYSQL}
    ID_MYSQL_CONTAINER=$(docker run -p 127.0.0.1:${PORT_LOCAL_MYSQL}:3306 --network ${NAME_DOCKER_NETWORK} --name ${NAME_MYSQL_CONTAINER} -e MYSQL_ROOT_PASSWORD=${mysql_root_pw} --restart=always -d mysql:${VERSION_MYSQL})

    # init wordpress database
    cp mysql/${NAME_SQL_FILE} ${NAME_SQL_FILE}
    MYSQL_WP_PW=$(gen_mysql_pw)
    sed -i -e "s/{password}/${MYSQL_WP_PW}/g" ${NAME_SQL_FILE}
    docker cp ${NAME_SQL_FILE} ${ID_MYSQL_CONTAINER}:/
    run_to_success docker exec ${ID_MYSQL_CONTAINER} mysql -uroot -p${mysql_root_pw} -e "exit"
    docker exec ${ID_MYSQL_CONTAINER} bash -c "mysql -uroot -p${mysql_root_pw} < /${NAME_SQL_FILE}"
    docker exec ${ID_MYSQL_CONTAINER} rm /${NAME_SQL_FILE}
}

function deploy_lap() {
    sed -i "s/DOMAIN_NAME/${DOMAIN}/g" docker-lap/apache2/default-ssl.conf
    docker build -t ${NAME_DOCKER_LAP}:${VERSION_DOCKER_LAP} ${PATH_TO_DOCKER_LAP}
}

function deploy_wordpress() {
    wget https://wordpress.org/wordpress-${VERSION_WORDPRESS}.tar.gz
    tar zxf wordpress-${VERSION_WORDPRESS}.tar.gz -C /opt
    rm wordpress-${VERSION_WORDPRESS}.tar.gz
    #config wp configure file
    cp ${DIR_WP_APP}/wp-config-sample.php ${DIR_WP_APP}/wp-config.php
    sed -i "s/database_name_here/${MYSQL_WP_DATABASE}/g" ${DIR_WP_APP}/wp-config.php
    sed -i "s/username_here/${MYSQL_WP_NAME}/g" ${DIR_WP_APP}/wp-config.php
    sed -i "s/password_here/${MYSQL_WP_PW}/g" ${DIR_WP_APP}/wp-config.php
    sed -i "s/localhost/${NAME_MYSQL_CONTAINER}/g" ${DIR_WP_APP}/wp-config.php
    sed -i '/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d' ${DIR_WP_APP}/wp-config.php
    curl https://api.wordpress.org/secret-key/1.1/salt > ${DIR_WP_APP}/temp
    sed -i '/$table_prefix/r /opt/wordpress/temp' ${DIR_WP_APP}/wp-config.php
    rm ${DIR_WP_APP}/temp
    sed -i 's/\r//g' ${DIR_WP_APP}/wp-config.php
    mkdir ${DIR_WP_APP}/wp-content/uploads

    chmod -R 755 ${DIR_WP_APP}
    docker run --rm -v ${DIR_WP_APP}:/var/www/html ${NAME_DOCKER_LAP}:${VERSION_DOCKER_LAP} chown -R www-data:www-data /var/www/html
}

function deploy_https() {
    tmp_id=$(docker run -d --name acme_sign -p 80:80 -v ${DIR_WP_APP}:/var/www/html -v ${PWD}/docker-lap/apache2-reg-ssl:/etc/apache2/sites-enabled ${NAME_DOCKER_LAP}:${VERSION_DOCKER_LAP})

    git clone https://github.com/acmesh-official/acme.sh.git
    pushd acme.sh
    ./acme.sh --upgrade --auto-upgrade
    ./acme.sh --set-default-ca --server letsencrypt
    ./acme.sh --issue -d ${DOMAIN} -w ${DIR_WP_APP}
    ./acme.sh --install-cert -d ${DOMAIN} \
        --key-file       ${DIR_HTTPS_KEYS}/${DOMAIN}.key  \
        --fullchain-file ${DIR_HTTPS_KEYS}/${DOMAIN}.crt \
        --ca-file        ${DIR_HTTPS_KEYS}/${DOMAIN}.ca.crt \
        --reloadcmd      "docker restart wordpress"
    popd
    rm -rf acme.sh

    docker stop ${tmp_id}
    docker rm ${tmp_id}
}

function run_wordpress() {
    docker run -d --name wordpress --restart=always --network ${NAME_DOCKER_NETWORK} -p 80:80 -p 443:443 -v ${DIR_WP_APP}:/var/www/html -v ${DIR_HTTPS_KEYS}:/etc/apache2/ssl ${NAME_DOCKER_LAP}:${VERSION_DOCKER_LAP}
}


function print-usage()
{
    echo -e "Usage: bash deploy.sh [OPTION]..."
    echo -e "options."
    echo -e "\t-d\troot domain name"
}

while getopts 'd:' arg
do
    case ${arg} in
        d)
            DOMAIN=${OPTARG}
            ;;
        *)
            print-usage
            exit 1
            ;;
    esac
done

if [ "${DOMAIN}" == "" ]
then
    print-usage
    exit 2
fi

mkdir -p ${DIR_HTTPS_KEYS}
create_docker_network
deploy_mysql
deploy_lap
deploy_wordpress
deploy_https
run_wordpress
