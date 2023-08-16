#!sh

NAME_DOCKER_NETWORK=wp-net
VERSION_MYSQL=5.7
NAME_MYSQL_CONTAINER=mysql
ID_MYSQL_CONTAINER=''
PORT_LOCAL_MYSQL=3600

NAME_SQL_FILE=wordpress.sql

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
    ID_MYSQL_CONTAINER=$(docker run -p 127.0.0.1:${PORT_LOCAL_MYSQL}:3306 --network ${NAME_DOCKER_NETWORK} --name ${NAME_MYSQL_CONTAINER} -e MYSQL_ROOT_PASSWORD=${mysql_root_pw} -d mysql:${VERSION_MYSQL})

    # init wordpress database
    cp mysql/${NAME_SQL_FILE} ${NAME_SQL_FILE}
    mysql_wp_pw=$(gen_mysql_pw)
    sed -i -e "s/{password}/${mysql_wp_pw}/g" ${NAME_SQL_FILE}
    docker cp ${NAME_SQL_FILE} ${ID_MYSQL_CONTAINER}:/
    docker exec ${ID_MYSQL_CONTAINER} bash -c "mysql -uroot -p${mysql_root_pw} < /${NAME_SQL_FILE}"
    docker exec ${ID_MYSQL_CONTAINER} rm /${NAME_SQL_FILE}
}

create_docker_network
deploy_mysql
