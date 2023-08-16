create database wordpress;

create user 'wordpress'@'%' identified by '{password}';
grant all on wordpress.* to 'wordpress'@'%' with grant option;
