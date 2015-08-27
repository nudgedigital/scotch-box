#! /bin/bash


# Remove any existing aliases
if [ -d /var/www/aliases ]; then
  echo "Removing any existing aliases"
  sudo find /var/www/aliases -maxdepth 1 -type l -exec rm -f {} \;
else
  echo "Creating new alias folder"
  sudo mkdir /var/www/aliases
fi

cd /var/www/

for d in /var/www/* ; do
  BASE=$(basename $d);
  if [ $BASE == 'aliases' ]; then
    continue;
  fi
  DIR=$(dirname $d);
  ALIAS='';

  if [ -f $d/.scotchroot ]; then
    sudo sed 's/^M$//' $d/.scotchroot >$d/.scotchroot.tmp && mv $d/.scotchroot.tmp $d/.scotchroot
    sudo tr -d '\r' < $d/.scotchroot > $d/.scotchroot.tmp && mv $d/.scotchroot.tmp $d/.scotchroot
    ALIAS=$(<$d/.scotchroot);
  fi

  if [ ! -e $DIR/aliases/$BASE.local ]; then
    echo "Creating new alias for $d/$ALIAS aliases/$BASE.local"
    sudo ln -s $d/$ALIAS aliases/$BASE.local
    #sudo ln -s $d/$ALIAS $DIR/aliases/$BASE.local
  fi

  if [ ! -e $DIR/aliases/www.$BASE.local ]; then
    echo "Creating new alias for  $d/$ALIAS  aliases/www.$BASE.local"
    sudo ln -s $d/$ALIAS  aliases/www.$BASE.local
    #sudo ln -s $d/$ALIAS  $DIR/aliases/www.$BASE.local
  fi
done

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
sudo echo "VirtualDocumentRoot /var/www/%0" >> /etc/apache2/mods-available/vhost_alias.conf

sudo echo "<Directory '/var/www'>" >> /etc/apache2/mods-available/vhost_alias.conf
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

# Install phpmyadmin silently
#echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
#echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
#echo "phpmyadmin phpmyadmin/mysql/admin-user string root" | debconf-set-selections
#echo "phpmyadmin phpmyadmin/mysql/admin-pass password root" | debconf-set-selections
#echo "phpmyadmin phpmyadmin/mysql/app-pass password" |debconf-set-selections
#echo "phpmyadmin phpmyadmin/app-password-confirm password" | debconf-set-selections
#apt-get -q -y install phpmyadmin

# Set some very lax php.ini settings for local development
upload_max_filesize=100M
post_max_size=100M
max_execution_time=600
max_input_time=600
memory_limit=512M
for key in upload_max_filesize post_max_size max_execution_time max_input_time memory_limit
do
 sed -i "s/^\($key\).*/\1 $(eval echo = \${$key})/" /etc/php5/apache2/php.ini
done

echo "Updating repositories"
apt-get update

echo "Installing XDebug"
apt-get install -y php5-xdebug php5-xmlrpc mc default-jre

# XDEBUG
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

echo "Restarting Apache one last time..."
sudo service apache2 restart

# Uncomment for a nice solarized prompt (doesn't seem to work on windows)
# sudo echo "export PS1='\[\033[38;5;198m\]\u\[$(tput sgr0)\]\[\033[38;5;6m\]@\[$(tput sgr0)\]\[\033[38;5;172m\]\h\[$(tput sgr0)\]\[\033[38;5;1m\]:\[$(tput sgr0)\]\[\033[38;5;6m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\] \n\[$(tput sgr0)\]\[\033[38;5;172m\]\\$ \[$(tput sgr0)\]'" >> /home/vagrant/.profile
