#!/bin/bash -e
wpuser='ankoadmin'

echo "================================================================="
echo "Awesome WordPress Installer!!"
echo "================================================================="

#accept the dbpass
echo "MySQL root Password: "
read -e dbpass

# accept the name of our website
echo "Site Name (google.com): "
read -e sitename

echo "SSH Git:"
read -e git

dbname=${sitename//./_}
vhost_name=$dbname

# add a simple yes/no confirmation before we proceed
echo "Run Install? (y/n)"
read -e run

# if the user didn't say no, then go ahead an install
if [ "$run" == n ] ; then
exit
else

mysqlclient_username=${dbname:0:10}$(LC_CTYPE=C tr -dc A-Za-z0-9 < /dev/urandom | head -c 5)
mysqlclient_password=$(LC_CTYPE=C tr -dc A-Za-z0-9_\!\@\#\$\%\^\&\*\(\)-+= < /dev/urandom | head -c 12)

git clone $git "/var/www/$dbname.git" --bare
mkdir "/var/www/$dbname"
sudo chmod 777 -R "/var/www/$dbname"

cd "/var/www/$dbname"

# download the WordPress core files
wp core download

# create the wp-config file
wp core config --dbname=$dbname --dbuser=root --dbpass=$dbpass

# parse the current directory name
currentdirectory=${PWD##*/}

# generate random 12 character password
password=$(LC_CTYPE=C tr -dc A-Za-z0-9_\!\@\#\$\%\^\&\*\(\)-+= < /dev/urandom | head -c 12)

# create database, and install WordPress
wp db create

#create mysql user for wp site
mysql -uroot -p${dbpass} -e "CREATE USER ${mysqlclient_username}@localhost IDENTIFIED BY '${mysqlclient_password}';"
mysql -uroot -p${dbpass} -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${mysqlclient_username}'@'localhost';"
mysql -uroot -p${dbpass} -e "FLUSH PRIVILEGES;"

#change username and password
rm wp-config.php
wp core config --dbname=$dbname --dbuser=$mysqlclient_username --dbpass=$mysqlclient_password

wp core install --url="http://$sitename" --title="$sitename" --admin_user="$wpuser" --admin_password="$password" --admin_email="user@example.org"

# configure vhost
sudo bash -c "cat > /etc/apache2/sites-available/$vhost_name.conf" <<EOF
<VirtualHost *:80>
        ServerAdmin support@ankocorp.com
        ServerName $sitename
        DocumentRoot /var/www/$vhost_name/
        <Directory />
                Options None
                AllowOverride None
                Order deny,allow
                deny from all
        </Directory>
        <Directory /var/www/$vhost_name>
                Order allow,deny
                allow from all
                AllowOverride FileInfo
                Options +FollowSymLinks
        </Directory>
</VirtualHost>
EOF

sudo a2ensite $vhost_name
sudo service apache2 reload

wp plugin install https://s3.amazonaws.com/public-anko/plugins/wp-sync-db.zip --activate
wp plugin install https://s3.amazonaws.com/public-anko/plugins/wp-sync-db-media-files.zip --activate

echo "================================================================="
echo "Installation is complete. Your username/password is listed below."
echo ""
echo "Username: $wpuser"
echo "Password: $password"
echo ""
echo "================================================================="

fi