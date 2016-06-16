#! /bin/bash

source /vagrant/config

echo "
 _____ _____ ____  _____ _____    ____  _____ _____ _____ _____ _____ __    
|   | |  |  |    \|   __|   __|  |    \|     |   __|     |_   _|  _  |  |   
| | | |  |  |  |  |  |  |   __|  |  |  |-   -|  |  |-   -| | | |     |  |__ 
|_|___|_____|____/|_____|_____|  |____/|_____|_____|_____| |_| |__|__|_____|
============================================================================
                         DEV MACHINE PROVISIONER
============================================================================

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
sudo a2enmod rewrite  > /dev/null 2>&1

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
sudo a2enmod vhost_alias > /dev/null 2>&1

# enable Apache SSL mod
sudo a2enmod ssl > /dev/null 2>&1

# set default ssl vhost
sudo a2ensite default-ssl > /dev/null 2>&1

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
sudo locale-gen en_GB.UTF-8 > /dev/null 2>&1

echo "Adding composer vendor folders to path"
sudo echo "PATH='$PATH:~/.composer/vendor/bin'" >> /home/vagrant/.profile

echo "Installing Drush"
sudo apt-get install -y drush > /dev/null 2>&1

echo "Installing phpmyadmin"
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-user string root" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password root" | debconf-set-selections
sudo apt-get install -y phpmyadmin > /dev/null 2>&1

# phpmyadmin configuration
sudo touch /etc/phpmyadmin/conf.d/overrides.php
sudo echo "
<?php

\$cfg['Servers'][1]['auth_type'] = 'config';
\$cfg['Servers'][1]['user'] = 'root';
\$cfg['Servers'][1]['password'] = 'root';

" >> /etc/phpmyadmin/conf.d/overrides.php
sudo chmod 755 /etc/phpmyadmin/conf.d/overrides.php

sudo apt-get -y install phpmyadmin > /dev/null 2>&1
sudo ln -s /usr/share/phpmyadmin/ /var/www/aliases/phpmyadmin.local
sudo ln -s /usr/share/phpmyadmin/ /var/www/aliases/www.phpmyadmin.local

echo PURGE | debconf-communicate phpmyadmin

echo "Configuring outbound e-mails"

echo "postfix postfix/mailname string dev.local" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Dev box'" | debconf-set-selections

sudo apt-get -y install mailutils > /dev/null 2>&1
sudo apt-get -y install ssmtp > /dev/null 2>&1

sudo echo "
FromLineOverride=YES
AuthUser=$email_address
AuthPass=$email_password
mailhub=smtp.gmail.com:587
UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf

#echo "Hello from your dev box!" | mail -s "this is the subject" "$email_address"
#echo "..Test email sent!"


echo "Configuring PHP"

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

echo "Configuring MySQL"
sudo sed '/\[mysqld\]/a \
skip_name_resolve\' -i /etc/mysql/my.cnf

echo "Restarting Apache"
sudo service apache2 restart > /dev/null 2>&1

# Build tools
sudo npm install --global gulp-cli > /dev/null 2>&1

# Run the on boot functions
echo "Creating new symbolic links"
sudo dos2unix /vagrant/onboot.sh > /dev/null 2>&1
bash /vagrant/onboot.sh > /dev/null 2>&1

# At the on boot functions
echo "Adding onboot script"
sudo echo 'bash /vagrant/onboot.sh' >> /etc/rc.local

# Import any databases
for d in /var/www/*.sql ; do
  echo "Importing existing database $d"
  mysql -u root -proot < $d;
done

# Find all folders with a gulp file
#echo "Looking for NPM dependencies to install.. this may take a while!"
#for f in $(find /var/www/ -name 'gulpfile.js'); do
#  DIR=$(dirname $f);
#  BASE=$(basename $f);
#  cd $DIR
#  sudo npm link gulp > /dev/null 2>&1
#  sudo npm install > /dev/null 2>&1
#done


echo "Provisioning complete!"