#!/usr/bin/env bash

# Install command-line tools using Homebrew.

DEV_SETUP_DIR=`pwd`

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Check for Homebrew,
# Install if we don't have it
if test ! $(which brew); then
  echo "Installing homebrew..."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Make sure we’re using the latest Homebrew.
brew update

brew install node

# Remove outdated versions from the cellar.
brew cleanup

npm install -g coffee-script
npm install -g grunt-cli
npm install -g jshint
npm install -g eslint
npm install -g eslint-plugin-react
npm install -g lodash-cli


##===================================##
##      INSTALL LAMP DEV STACK       ##
##===================================##
echo "Replacing Built-in Apache with Homebrew version"
sudo apachectl stop
sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist 2>/dev/null
brew install homebrew/apache/httpd24 --with-privileged-ports --with-http2
PATH_HTTPD24=`brew --prefix httpd24`
sudo cp -v $PATH_HTTPD24/homebrew.mxcl.httpd24.plist /Library/LaunchDaemons
sudo chown -v root:wheel /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist
sudo chmod -v 644 /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist
sudo launchctl load /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist

HTTPD_CONF_PATH=/usr/local/etc/apache2/2.4/httpd.conf

# Make sure we have a Sites folder set up
if [ ! -d ~/Sites ]; then
  mkdir ~/Sites
fi
if [ ! -d ~/Sites/logs ]; then
  mkdir ~/Sites/logs
fi
if [ ! -d ~/Sites/vhosts ]; then
  mkdir ~/Sites/vhosts
fi
if [ ! -d ~/Sites/ssl ]; then
  cp -a "$DEV_SETUP_DIR/init/apache/ssl" ~/Sites/
fi
if [ ! -f ~/Sites/index.html ]; then
  echo "<h1>My User Web Root</h1>" > ~/Sites/index.html
fi
if [ ! -f ~/Sites/httpd-vhosts.conf ]; then
  cp "$DEV_SETUP_DIR/init/apache/httpd-vhosts.conf" ~/Sites/
  sed -E -i \
    -e "s|USERNAME|`whoami`|" \
    ~/Sites/httpd-vhosts.conf
fi

# Update Apache config:
# 1. Set default webroot to ~/Sites (and update corresponding Directory block)
# 2. Set AllowOverride to All for the default directory only
# 3. Enable required modules
# 4. ""
# 5. ""
# 6. ""
# 7. Include SSL config
# 8. Set User to your current user
# 9. Set Group to 'staff'
sed -E -i.orig \
  -e "s|/usr/local/var/www/htdocs|/Users/`whoami`/Sites|" \
  -e "/Directory \"?\/Users\/`whoami`\/Sites\"?/,/<\/Directory>/ s|AllowOverride None|AllowOverride All|" \
  -e "s|#(LoadModule.*mod_rewrite.so)|\1|" \
  -e "s|#(LoadModule.*mod_socache_shmcb.so.so)|\1|" \
  -e "s|#(LoadModule.*mod_rewrite.so)|\1|" \
  -e "s|#(LoadModule.*mod_vhost_alias.so)|\1|" \
  -e "s|#(Include.*httpd-ssl.conf)|\1|" \
  -e "s|^User.*|User `whoami`|" \
  -e "s|^Group.*|Group staff|" \
  $HTTPD_CONF_PATH


# 10. Add vhosts include
cat <<EOT >> $HTTPD_CONF_PATH

# Include our VirtualHosts
Include /Users/`whoami`/Sites/httpd-vhosts.conf
EOT

# Set up Self-signed certificate
openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -keyout /usr/local/etc/apache2/2.4/server.key -out /usr/local/etc/apache2/2.4/server.crt


# Install Multiple PHP versions
brew install homebrew/php/php56 --with-httpd24
brew install homebrew/php/php56-xdebug
brew install homebrew/php/php56-imagick
brew unlink php56
brew install homebrew/php/php70 --with-httpd24
brew install homebrew/php/php70-xdebug
brew install homebrew/php/php70-imagick

# Install Xdebug Toggler Script
brew install xdebug-osx

# Install PHP Switcher utility script
curl -L https://gist.github.com/w00fz/142b6b19750ea6979137b963df959d11/raw > /usr/local/bin/sphp
chmod +x /usr/local/bin/sphp

# Update Apache config for PHP:
# 1. Replace paths to specific PHP verisons with links managed by PHP switcher utility
# 2. Add acomment to remind us why we've changed the linked module paths
# 3. Comment out all but one PHP module
# 4. Add dirctives to handle php index files
sed -E -i \
  -e "s|/usr/local/Cellar/php.*(libphp[57].so)|/usr/local/lib/\1|" \
  -e "0,/LoadModule php/ s|LoadModule php|# Brew PHP LoadModule for php switcher\n&|" \
  -e "s|(LoadModule php5_module)|#\1|" \
  -e "/<IfModule dir_module>/,/<\/IfModule>/ s|DirectoryIndex index.html|DirectoryIndex index.php index.html|" \
  $HTTPD_CONF_PATH

# 5. Add PHP handler
perl -i -pe 'BEGIN{undef $/;} s|(<IfModule dir_module>.*</IfModule>)|$1\n\n<FilesMatch \.php\$>\n    SetHandler application/x-httpd-php\n</FilesMatch>|smg' $HTTPD_CONF_PATH

# Set PHP to v7 (This sets up symlinks, etc. for the first time)
sphp 70

# Restart apache to ensure configuration changes have taken effect:
sudo apachectl -k restart


#install MariaDB (MySQL)
brew install mariadb
# mysql_install_db
mysql.server start
brew services start mariadb

#install Dnsmasq to resolve *.dev domains
brew install dnsmasq
if [ ! -d /usr/local/etc ]; then
  mkdir /usr/local/etc
fi
echo 'address=/.dev/127.0.0.1' > /usr/local/etc/dnsmasq.conf
sudo brew services start dnsmasq
sudo mkdir -v /etc/resolver
sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolver/dev'

# Wait until all automated stuff is complete before running commands that require interaction
mysql_secure_installation
