#! /bin/bash

source /vagrant/config.sh

echo "
 _____ _____ ____  _____ _____    ____  _____ _____ _____ _____ _____ __    
|   | |  |  |    \|   __|   __|  |    \|     |   __|     |_   _|  _  |  |   
| | | |  |  |  |  |  |  |   __|  |  |  |-   -|  |  |-   -| | | |     |  |__ 
|_|___|_____|____/|_____|_____|  |____/|_____|_____|_____| |_| |__|__|_____|
===========================================================================
                         DEV MACHINE PROVISIONER
===========================================================================


";


# Remove any existing aliases
if [ -d /var/www/aliases ]; then
  echo "Removing any existing aliases"
  sudo find /var/www/aliases -maxdepth 1 -type l -exec rm -f {} \;
else
  echo "Creating new alias folder"
  sudo mkdir /var/www/aliases
fi

if [ -d /var/www/phpmyadmin ]; then
  echo "Removing your local PHPMyAdmin"
  sudo rm -rf /var/www/phpmyadmin
  sudo rm /var/www/aliases/www.phpmyadmin.local
  sudo rm /var/www/aliases/phpmyadmin.local
fi


# create and enable rewrite loader
echo "Creating Apache rewrite.load"
sudo echo "LoadModule rewrite_module /usr/lib/apache2/modules/mod_rewrite.so" > /etc/apache2/mods-available/rewrite.load

# enable Apache mod_rewrite
sudo a2enmod rewrite

# create and enable vhost_alias loader
echo "Creating Apache vhost_alias.load"
sudo echo "LoadModule vhost_alias_module /usr/lib/apache2/modules/mod_vhost_alias.so" > /etc/apache2/mods-available/vhost_alias.load

# create our vhost_alias.conf file
echo "Creating Apache vhost_alias.conf"
sudo echo "UseCanonicalName Off" > /etc/apache2/mods-available/vhost_alias.conf
sudo echo "VirtualDocumentRoot /var/www/aliases/%0" >> /etc/apache2/mods-available/vhost_alias.conf

sudo echo "<Directory '/var/www/aliases'>" >> /etc/apache2/mods-available/vhost_alias.conf
sudo echo "Options Indexes FollowSymLinks MultiViews" >> /etc/apache2/mods-available/vhost_alias.conf
sudo echo "AllowOverride all" >> /etc/apache2/mods-available/vhost_alias.conf
sudo echo "Order allow,deny" >> /etc/apache2/mods-available/vhost_alias.conf
sudo echo "allow from all" >> /etc/apache2/mods-available/vhost_alias.conf
sudo echo "</Directory>" >> /etc/apache2/mods-available/vhost_alias.conf

# enable Apache mod_rewrite
sudo a2enmod vhost_alias

# enable Apache SSL mod
sudo a2enmod ssl

# set default ssl vhost
sudo a2ensite default-ssl

echo "Updating repositories"
sudo apt-get update > /dev/null 2>&1

echo "Installing dos2unix"
sudo apt-get install -y dos2unix > /dev/null 2>&1

echo "Installing XDebug"
sudo apt-get install -y php5-xdebug php5-xmlrpc > /dev/null 2>&1

# XDEBUG configuration
echo "; xdebug
xdebug.remote_connect_back = 1
xdebug.remote_enable = 1
xdebug.remote_handler = \"dbgp\"
xdebug.remote_port = 9000
xdebug.var_display_max_children = 512
xdebug.var_display_max_data = 1024
xdebug.var_display_max_depth = 10
xdebug.idekey = \"PHPSTORM\"" >> /etc/php5/apache2/php.ini

echo "Setting locale correctly"
sudo locale-gen en_GB.UTF-8

echo "Adding composer vendor folders to path"
sudo echo "PATH='$PATH:~/.composer/vendor/bin'" >> /home/vagrant/.profile

echo "Installing Drush"
sudo apt-get install -y drush > /dev/null 2>&1

echo "Installing phpmyadmin"
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-user string root" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password root" | debconf-set-selections
sudo apt-get -y install phpmyadmin > /dev/null 2>&1

# phpmyadmin configuration
sudo touch /usr/share/phpmyadmin/config.inc.php
sudo chmod 644 /usr/share/phpmyadmin/config.inc.php

sudo echo "
<?php

\$cfg['blowfish_secret'] = 'a8b7c6d'; /* YOU MUST FILL IN THIS FOR COOKIE AUTH! */

\$cfg['Servers'][1]['auth_type'] = 'config';
\$cfg['Servers'][1]['user'] = 'root';
\$cfg['Servers'][1]['password'] = 'root'; " >> /usr/share/phpmyadmin/config.inc.php

echo "Configuring outbound e-mails"
sudo apt-get -y install postfix mailutils libsasl2-2 ca-certificates libsasl2-modules  > /dev/null 2>&1


echo "
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/postfix/cacert.pem
smtp_use_tls = yes" >> /etc/postfix/main.cf

echo "[smtp.gmail.com]:587 $email_address:$email_password" >>  /etc/postfix/sasl_passwd

sudo chmod 400 /etc/postfix/sasl_passwd
sudo postmap /etc/postfix/sasl_passwd
cat /etc/ssl/certs/Thawte_Premium_Server_CA.pem | sudo tee -a /etc/postfix/cacert.pem

sudo apt-get -y install phpmyadmin > /dev/null 2>&1
sudo ln -s /usr/share/phpmyadmin/ /var/www/aliases/phpmyadmin.local
sudo ln -s /usr/share/phpmyadmin/ /var/www/aliases/www.phpmyadmin.local
sudo /etc/init.d/postfix reload


echo "this is the body" | mail -s "this is the subject" $address



# Set some very lax php.ini settings for local development
upload_max_filesize=100M
post_max_size=100M
max_execution_time=600
max_input_time=600
memory_limit=1024M
display_errors=On
for key in upload_max_filesize post_max_size max_execution_time max_input_time memory_limit display_errors
do
 sed -i "s/^\($key\).*/\1 $(eval echo = \${$key})/" /etc/php5/apache2/php.ini
done

echo "Restarting Apache one last time..."
sudo service apache2 restart

# Build tools
sudo npm install --global gulp-cli > /dev/null 2>&1

# Run the on boot functions
dos2unix /vagrant/onboot.sh

# Find all folders with a  gulp file
echo "Looking for NPM dependencies to install.. this may take a while!"
for f in $(find /var/www/ -name 'gulpfile.js'); do
  DIR=$(dirname $f);
  BASE=$(basename $f);
  cd $DIR
  sudo npm link gulp > /dev/null 2>&1
  sudo npm install > /dev/null 2>&1
  echo "..Node packages installed for $BASE"
done

# Import any databases
for d in /var/www/*.sql ; do
  echo "Importing existing database $d"
  mysql -u root -proot < $d;
done