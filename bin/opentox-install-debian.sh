#!/bin/bash
#Installation is tested on Debian Lenny Ubuntu 9.04
#Update the system

ERRLOG='install_err.log'
INSTALLLOG='install_log.log'
DATE=$(date +%Y/%m/%d\ %H:%M:%S)

echo "================================================="
echo "Please enshure that the sudo package is installed"
echo "on your system. "
echo "On Ubuntu Linux sudo is installed by default."
echo "If you are unshure check with it 'sudo ls'"
echo "and installed it with 'apt-get install sudo'"
echo "and add your username with visudo."
echo "================================================="
echo -n "To continue installation press y: "
read answer
if [ "$answer" != "y" ]
then
  echo "exiting the script..."
  exit 1
fi

echo "opentox webservice install log - " $DATE > $INSTALLLOG
echo "Installing: build-essential"
sudo apt-get install build-essential >> $INSTALLLOG 2>>$ERRLOG
echo "Installing: ruby 1.8 with its dev files"
sudo apt-get install ruby ruby1.8-dev >> $INSTALLLOG 2>>$ERRLOG
echo "Installing: gems rdoc rubygems and rake"
sudo apt-get install gems rdoc rubygems rake >> $INSTALLLOG 2>>$ERRLOG

echo "Installing rubygems from source. This may take some time"
wget http://rubyforge.org/frs/download.php/60718/rubygems-1.3.5.tgz >> $INSTALLLOG 2>>$ERRLOG
tar xzfv rubygems-1.3.5.tgz 2>>$ERRLOG
cd rubygems-1.3.5 >> $INSTALLLOG 2>>$ERRLOG
sudo ruby setup.rb 2>>$ERRLOG
cd ..

echo "Adding http://gems.github.com to ruby gem sources"
sudo gem sources -a http://gems.github.com >> $INSTALLLOG 2>>$ERRLOG

#for debian lenny:
echo "Installing packages: zlib1g-dev tcl curl perl ssh tcl tk8.5"
sudo apt-get install zlib1g-dev tcl curl perl ssh tcl tk8.5  >> $INSTALLLOG 2>>$ERRLOG
echo "Installing git from source"
wget http://www.kernel.org/pub/software/scm/git/git-1.6.5.2.tar.gz >> $INSTALLLOG 2>>$ERRLOG
tar xzfv git-1.6.5.2.tar.gz  2>>$ERRLOG
cd git-1.6.5.2 >> $INSTALLLOG 2>>$ERRLOG
./configure 2>>$ERRLOG
make 2>>$ERRLOG
make install 2>>$ERRLOG

echo "Installing the opentox webservices"
mkdir webservices >> $INSTALLLOG 2>>$ERRLOG
cd webservices >> $INSTALLLOG 2>>$ERRLOG

git clone git://github.com/helma/opentox-compound.git >> $INSTALLLOG 2>>$ERRLOG
git clone git://github.com/helma/opentox-feature.git >> $INSTALLLOG 2>>$ERRLOG
git clone git://github.com/helma/opentox-dataset.git >> $INSTALLLOG 2>>$ERRLOG
git clone git://github.com/helma/opentox-algorithm.git >> $INSTALLLOG 2>>$ERRLOG
git clone git://github.com/helma/opentox-model.git >> $INSTALLLOG 2>>$ERRLOG
git clone git://github.com/helma/opentox-test.git  >> $INSTALLLOG 2>>$ERRLOG

cd opentox-compound >> $INSTALLLOG 2>>$ERRLOG
git checkout -b development origin/development >> $INSTALLLOG 2>>$ERRLOG
cd ../opentox-feature >> $INSTALLLOG 2>>$ERRLOG
git checkout -b development origin/development >> $INSTALLLOG 2>>$ERRLOG
cd ../opentox-dataset >> $INSTALLLOG 2>>$ERRLOG
git checkout -b development origin/development >> $INSTALLLOG 2>>$ERRLOG
cd ../opentox-algorithm >> $INSTALLLOG 2>>$ERRLOG
git checkout -b development origin/development >> $INSTALLLOG 2>>$ERRLOG
cd ../opentox-model >> $INSTALLLOG 2>>$ERRLOG
git checkout -b development origin/development >> $INSTALLLOG 2>>$ERRLOG
cd .. >> $INSTALLLOG 2>>$ERRLOG
git clone git://github.com/helma/opentox-ruby-api-wrapper.git >> $INSTALLLOG 2>>$ERRLOG
cd opentox-ruby-api-wrapper >> $INSTALLLOG 2>>$ERRLOG
git checkout -b development origin/development >> $INSTALLLOG 2>>$ERRLOG
rake install >> $INSTALLLOG 2>>$ERRLOG


cd ../opentox-compound >> $INSTALLLOG 2>>$ERRLOG
echo "Installing libopenssl-ruby"
sudo apt-get install libopenssl-ruby >> $INSTALLLOG 2>>$ERRLOG
echo "Installing dtach"
rake dtach:install >> $INSTALLLOG 2>>$ERRLOG
echo "Installing openbabel"
rake openbabel:install >> $INSTALLLOG 2>>$ERRLOG

#debian lenny missed liblink:
ln -s /usr/local/lib/libopenbabel.so.3 /usr/lib/libopenbabel.so.3 >> $INSTALLLOG 2>>$ERRLOG

rake redis:download >> $INSTALLLOG 2>>$ERRLOG
rake redis:install >> $INSTALLLOG 2>>$ERRLOG
#edit /home/[username]/.opentox/config/test.yaml set :base_dir: /home/[username]/webservices
sudo apt-get install libgsl0-dev >> $INSTALLLOG 2>>$ERRLOG
sudo apt-get install swig >> $INSTALLLOG 2>>$ERRLOG
sudo apt-get install curl >> $INSTALLLOG 2>>$ERRLOG
cd ../opentox-algorithm >> $INSTALLLOG 2>>$ERRLOG
echo "Installing fminer"
rake fminer:install >> $INSTALLLOG 2>>$ERRLOG
sudo apt-get install libsqlite3-dev >> $INSTALLLOG 2>>$ERRLOG


mkdir ../opentox-model/db >> $INSTALLLOG 2>>$ERRLOG
