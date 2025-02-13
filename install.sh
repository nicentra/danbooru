#!/bin/bash

# Run: curl -L -s https://raw.githubusercontent.com/danbooru/danbooru/master/INSTALL.debian -o install.sh ; chmod +x install.sh ; ./install.sh

export RUBY_VERSION=3.1.2
export GITHUB_INSTALL_SCRIPTS=https://raw.githubusercontent.com/nicentra/danbooru/master/script/install
export VIPS_VERSION=8.12.1

if [[ "$(whoami)" != "root" ]] ; then
  echo "You must run this script as root"
  exit 1
fi

verlte() {
  [ "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

verlt() {
  [ "$1" = "$2" ] && return 1 || verlte $1 $2
}

echo "* DANBOORU INSTALLATION SCRIPT"
echo "*"
echo "* This script will install all the necessary packages to run Danbooru on a   "
echo "* Debian server."
echo
echo -n "* Enter the hostname for this server (ex: danbooru.donmai.us): "
read HOSTNAME

if [[ -z "$HOSTNAME" ]] ; then
  echo "* Must enter a hostname"
  exit 1
fi

# Install packages
echo "* Installing packages..."

if [ -n "$(uname -a | grep Ubuntu)" ] ; then
  LIBSSL_DEV_PKG=libssl-dev
  LIBJPEG_TURBO_DEV_PKG=libjpeg-turbo8-dev
else
  LIBSSL_DEV_PKG=$( verlt `lsb_release -sr` 9.0 && echo libssl-dev || echo libssl1.0-dev )
  LIBJPEG_TURBO_DEV_PKG=libjpeg62-turbo-dev
fi
apt-get update
apt-get -y install apt-transport-https
apt-get -y install zlib1g-dev libglib2.0-dev
apt-get -y install $LIBSSL_DEV_PKG build-essential automake libxml2-dev libxslt-dev ncurses-dev sudo libreadline-dev flex bison ragel redis git curl libcurl4-openssl-dev sendmail-bin sendmail nginx ssh coreutils ffmpeg mkvtoolnix libvips42 libvips-dev
apt-get -y install libpq-dev postgresql-client
apt-get -y install liblcms2-dev $LIBJPEG_TURBO_DEV_PKG libexpat1-dev libgif-dev libpng-dev libexif-dev
apt-get -y install gcc g++
apt-get -y install exiftool perl perl-modules

# curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
# echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
# curl -sSL https://deb.nodesource.com/setup_10.x | sudo -E bash -
# apt-get update
# apt-get -y install nodejs yarn
apt-get remove cmdtest

if [ $? -ne 0 ]; then
  echo "* Error installing packages; aborting"
  exit 1
fi

# compile and install libvips (the version in apt is too old)
# cd /tmp
# wget -q https://github.com/libvips/libvips/releases/download/v$VIPS_VERSION/vips-$VIPS_VERSION.tar.gz
# tar xzf vips-$VIPS_VERSION.tar.gz
# cd vips-$VIPS_VERSION
# ./configure --prefix=/usr
# make install
# ldconfig

# Create user account
useradd -m danbooru
chsh -s /bin/bash danbooru
usermod -G danbooru,sudo danbooru

# Set up Postgres
export PG_VERSION=`pg_config --version | egrep -o '[0-9]{1,}' | head -1`

# Install rbenv
echo "* Installing rbenv..."
cd /tmp
sudo -u danbooru git clone https://github.com/sstephenson/rbenv.git ~danbooru/.rbenv
sudo -u danbooru touch ~danbooru/.bash_profile
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~danbooru/.bash_profile
echo 'eval "$(rbenv init -)"' >> ~danbooru/.bash_profile
sudo -u danbooru mkdir -p ~danbooru/.rbenv/plugins
sudo -u danbooru git clone https://github.com/sstephenson/ruby-build.git ~danbooru/.rbenv/plugins/ruby-build
sudo -u danbooru bash -l -c "RUBY_CONFIGURE_OPTS=--disable-install-doc rbenv install --verbose $RUBY_VERSION"
sudo -u danbooru bash -l -c "rbenv global $RUBY_VERSION"

# Install gems
echo "* Installing gems..."
sudo -u danbooru bash -l -c 'gem install --no-ri --no-rdoc bundler'

echo "* Install configuration scripts..."

# Update PostgreSQL
curl -L -s $GITHUB_INSTALL_SCRIPTS/postgresql_hba_conf -o /etc/postgresql/$PG_VERSION/main/pg_hba.conf
/etc/init.d/postgresql restart
sudo -u postgres createuser -s danbooru
sudo -u danbooru createdb danbooru2

# Setup nginx
curl -L -s $GITHUB_INSTALL_SCRIPTS/nginx.danbooru.conf -o /etc/nginx/sites-enabled/danbooru.conf
sed -i -e "s/__hostname__/$HOSTNAME/g" /etc/nginx/sites-enabled/danbooru.conf
/etc/init.d/nginx restart

# Setup danbooru account
echo "* Enter a new password for the danbooru account"
passwd danbooru

echo "* Setting up SSH keys for the danbooru account"
sudo -u danbooru ssh-keygen -t rsa -f ~danbooru/.ssh/id_rsa -N ""
sudo -u danbooru touch ~danbooru/.ssh/authorized_keys
sudo -u danbooru cat ~danbooru/.ssh/id_rsa.pub >> ~danbooru/.ssh/authorized_keys
sudo -u danbooru chmod 600 ~danbooru/.ssh/authorized_keys

mkdir -p /var/www/danbooru2/shared/config
mkdir -p /var/www/danbooru2/shared/data
mkdir -p /var/www/danbooru2/shared/data/preview
mkdir -p /var/www/danbooru2/shared/data/sample
chown -R danbooru:danbooru /var/www/danbooru2
curl -L -s $GITHUB_INSTALL_SCRIPTS/danbooru_local_config.rb.templ -o /var/www/danbooru2/shared/config/danbooru_local_config.rb

echo "* Almost done! You are now ready to deploy Danbooru onto this server."
echo "* Log into Github and fork https://github.com/danbooru/danbooru into"
echo "* your own repository. Clone your fork onto your local development"
echo "* machine and modify the following files:"
echo "*"
echo "*   config/application.rb (time zone)"
echo "*"
echo "* On the remote server you will want to modify this file:"
echo "*"
echo "*   /var/www/danbooru2/shared/config/danbooru_local_config.rb"
echo "*"
read -p "Press [enter] to continue..."
echo "* Commit your changes and push them to your fork. You are now ready to"
echo "* deploy with the following command:"
echo "*"
echo "*   bundle exec cap production deploy"
echo "*"
echo "* You can also run a server locally without having to deal with deploys"
echo "* by running the following command:"
echo "*"
echo "*   bundle install"
echo "*   bundle exec rake db:create db:migrate db:seed"
echo "*   bundle exec rails server"
echo "*   RAILS_ENV=production bin/rails server -b 0.0.0.0"
echo "*"
echo "* This will start a web process running on port 3000 that you can"
echo "* connect to. This is useful for development and testing purposes."
echo "* If something breaks post about it on the Danbooru Github. Good luck!"
