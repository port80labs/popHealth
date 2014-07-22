#!/bin/bash
# This is a script that finishes the setup for a popHealth instance on an Amazon EC2

VCERT='nmedw'
VMASTER='master'
V212='v2.1.2'
V300='v3.0.0'
LINK='https://github.com/pophealth/popHealth.git'
BRANCH=''
echo -n "$(tput setaf 4)"
echo "##############################################"
echo "#           popHealth Installation           #"
echo "##############################################"
echo -n "$(tput sgr0)"

# get the right version of the software
echo -n "$(tput setaf 7)"
PS3="Please choose which version of popHealth you want to install: "
options=("master" "3.0.0" "2.1.2" "certified")
select option in "${options[@]}"
do
  case $option in
    "certified")
      LINK='https://github.com/yoon/popHealth.git'
      BRANCH=$VCERT
      break;;
    "master")
      BRANCH=$VMASTER
      break;;
    "3.0.0")
      BRANCH=$V300
      break;;
    "2.1.2")
      BRANCH=$V212
      break;;
  esac
done
echo -n "$(tput sgr0)"
echo -n "$(tput setaf 4)Downloading popHealth code... $(tput sgr0)"
sudo rm -rf /home/pophealth/popHealth > /dev/null 2>&1
sudo git clone -b "$BRANCH" "$LINK" /home/pophealth/popHealth > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "$(tput setaf 1)Failed!$(tput sgr0)"
  echo "$(tput setaf 1)Error downloading the required code. Please try again.$(tput sgr0)"
  exit 3
fi

# extract and move the right location
sudo rm -rf /home/pophealth/popHealth/.ruby-version > /dev/null 2>&1
sudo chown -R pophealth:pophealth /home/pophealth/popHealth
echo "$(tput setaf 2)Complete$(tput sgr0)"

# get username and password for NLM
echo -n "$(tput setaf 7)Enter your NLM username and press [ENTER]: "
read username
echo -n "$(tput sgr0)"
if [ "$username" == '' ]; then
  echo "$(tput setaf 1)NLM username is required for the pophealth installation to continue. Please try again.$(tput sgr0)"
  exit 1
fi

echo -n "$(tput setaf 7)Enter your NLM password and press [ENTER]: "
read password
echo -n "$(tput sgr0)"
if [ "$password" == '' ]; then
  echo "$(tput setaf 1)NLM password is required for the pophealth installation to continue. Please try again.$(tput sgr0)"
  exit 2
fi

# get the measure bundle
echo -n "$(tput setaf 4)Downloading measure bundle definitions... $(tput sgr0)"
sudo rm -rf bundle-latest.zip /home/pophealth/bundle-latest.zip > /dev/null 2>&1
curl -fs -u $username:$password http://demo.projectcypress.org/bundles/bundle-latest.zip -o bundle-latest.zip
if [ $? -ne 0 ]; then
  echo "$(tput setaf 1)Failed!$(tput sgr0)"
  echo "$(tput setaf 1)Error downloading the measure bundle definitions. Perhaps the username and password are incorrect. Please try again.$(tput sgr0)"
  exit 3
fi
sudo mv -f bundle-latest.zip /home/pophealth/bundle-latest.zip
sudo chown -R pophealth:pophealth /home/pophealth/bundle-latest.zip > /dev/null 2>&1
echo "$(tput setaf 2)Complete$(tput sgr0)"

# remove any existing database
mongo pophealth-production --eval "db.dropDatabase()" > /dev/null 2>&1

# install gems and import bundle
sudo su - pophealth <<'EOF'
  cd popHealth
  echo -n "$(tput setaf 4)Installing required gems... $(tput sgr0)"
  bundle install --without develop test > /dev/null 2>&1
  echo "$(tput setaf 2)Complete$(tput sgr0)"
  echo -n "$(tput setaf 4)Importing measure bundles... $(tput sgr0)"
  RAILS_ENV=production bundle exec rake bundle:import[/home/pophealth/bundle-latest.zip,false,false,"*",true,true] > /dev/null 2>&1
  echo "$(tput setaf 2)Complete$(tput sgr0)"
EOF

# run rake tasks
sudo su - pophealth <<'EOF'
cd popHealth
echo -n "$(tput setaf 4)Initializing popHealth database (this may take some time.. get some coffee)... $(tput sgr0)"
RAILS_ENV=production bundle exec rake db:seed
RAILS_ENV=production bundle exec rake admin:create_admin_account
RAILS_ENV=production bundle exec rake assets:precompile > /dev/null 2>&1
rm .ruby-version > /dev/null 2>&1
echo "$(tput setaf 2)Complete$(tput sgr0)"
EOF

# start apache servers and start background job
echo -n "$(tput setaf 4)Starting servers and jobs... $(tput sgr0)"
sudo a2ensite popHealth > /dev/null 2>&1
sudo service apache2 restart > /dev/null 2>&1
sudo stop delayed_worker > /dev/null 2>&1
sudo start delayed_worker > /dev/null 2>&1
echo "$(tput setaf 2)Complete$(tput sgr0)"

IP=`curl -Lfs ifconfig.me` > /dev/null 2>&1
echo "$(tput setaf 2)Server Ready - Visit http://$IP/$(tput sgr0)"

echo -n "$(tput setaf 4)"
echo "##############################################"
echo "#       popHealth Installation Complete      #"
echo "##############################################"
echo -n "$(tput sgr0)"

exit 0
