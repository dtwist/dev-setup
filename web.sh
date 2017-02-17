#!/usr/bin/env bash

# Install command-line tools using Homebrew.

DEV_SETUP_DIR=pwd

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
npm install -g eslint-plugin-react
npm install -g lodash-cli



##===================================##
##      INSTALL LAMP DEV STACK       ##
##===================================##
echo "Replacing Built-in Apache with Homebrew version"
sudo apachectl stop
sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist 2>/dev/null
brew install httpd24 --with-privileged-ports --with-http2
PATH_HTTPD24=`brew --prefix httpd24`
sudo cp -v $PATH_HTTPD24/homebrew.mxcl.httpd24.plist /Library/LaunchDaemons
sudo chown -v root:wheel /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist
sudo chmod -v 644 /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist
sudo launchctl load /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist

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
  cp -a "$DEV_SETUP_DIR/apache/ssl" ~/Sites/
fi
if [ ! -f ~/Sites/index.html ]; then
  echo "<h1>My User Web Root</h1>" > ~/Sites/index.html
fi
if [ ! -f ~/Sites/httpd-vhosts.conf ]; then
  cp "$DEV_SETUP_DIR/apache/httpd-vhosts.conf" ~/Sites/
  sed -E -i '' \
    -e "s|{USERNAME}|`whoami`|" \
    ~/Sites/httpd-vhosts.conf
fi

# Update Apache config:
# 1. Set default webroot to ~/Sites (and update corresponding Directory block)
# 2. Set AllowOverride to All for the default directory only
# 3. Make sure mod_rewrite is enabled
# 4. Set User to your current user
# 5. Set Group to 'staff'
sed -E -i .orig \
  -e "s|/usr/local/var/www/htdocs|/Users/`whoami`/Sites|" \
  -e "/Directory \"?\/Users\/`whoami`\/Sites\"?/,/<\/Directory>/ s|AllowOverride None|AllowOverride All|" \
  -e "s|#(LoadModule.*mod_rewrite.so)|\1|" \
  -e "s|^User.*|User `whoami`|" \
  -e "s|^Group.*|Group staff|" \
  /usr/local/etc/apache2/2.4/httpd.conf


# 6. Add vhosts include
cat <<EOT >> /usr/local/etc/apache2/2.4/httpd.conf

# Include our VirtualHosts
Include /Users/`whoami`/Sites/httpd-vhosts.conf
EOT


# Install Multiple PHP versions
brew install php56 --with-httpd24
brew install php56-xdebug
brew install php56-imagick
brew unlink php56
brew install php70 --with-httpd24
brew install php70-xdebug
brew install php70-imagick

# Install Xdebug Toggler Script
brew install xdebug-osx

# Install PHP Switcher utility script
curl -L https://gist.github.com/w00fz/142b6b19750ea6979137b963df959d11/raw > /usr/local/bin/sphp
chmod +x /usr/local/bin/sphp

# Update Apache config for PHP:
# 1. Replace paths to specific PHP verisons with links managed by PHP switcher utility
# 2. Add acomment to remind us why we've changed the linked module paths
# 2. Comment out all but one PHP module
# 3. Add dirctives to handle php index files
sed -E -i '' \
  -e "s|/usr/local/Cellar/(php\d+)/.*(libphp\d.so)|/usr/local/lib/\2|" \
  -e "0,/LoadModule php/ s|LoadModule php|# Brew PHP LoadModule for `sphp` switcher\n&" \
  -e "s|(LoadModule php5_module)|#\1" \
  -e "/<IfModule dir_module>/,/</IfModule>/ s|DirectoryIndex index.html|DirectoryIndex index.php index.html|" \
  /usr/local/etc/apache2/2.4/httpd.conf

# 3. Add PHP handler
perl -i -pe 'BEGIN{undef $/;} s/(<IfModule dir_module>.*</IfModule>)/$1\n\n<FilesMatch \.php$>\n    SetHandler application/x-httpd-php\n</FilesMatch>/smg' /usr/local/etc/apache2/2.4/httpd.conf

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
