# These actions will be run at provisioning time

# Install Apache and PHP
sudo apt-get update
sudo apt-get install apache2 -y
sudo apt-get install php libapache2-mod-php php-mcrypt php-mysql -y
sudo systemctl restart apache2

# Delete default web site and download a new one
sudo rm /var/www/html/index.html
sudo apt-get install wget -you
sudo wget https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/index.php -P /var/www/html/
sudo wget https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/styles.css -P /var/www/html/
sudo wget https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/apple-touch-icon.png -P /var/www/html/
sudo wget https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/favicon.ico -P /var/www/html/

# Build RAID0 for data disks
sudo wget https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/build-raid.sh -P /root/
sudo chmod 755 /root/build-raid.sh
sudo /root/build-raid.sh
