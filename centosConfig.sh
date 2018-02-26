# These actions will be run at provisioning time

# Install Apache and PHP
sudo yum update
sudo yum install -y httpd php curl wget
sudo systemctl start httpd
sudo systemctl enable httpd
sudo systemctl restart httpd

# Delete default web site and download a new one
sudo rm /var/www/html/index.html
sudo apt-get install wget -you
sudo wget https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/index.php -P /var/www/html/
sudo wget https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/styles.css -P /var/www/html/
sudo wget https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/apple-touch-icon.png -P /var/www/html/
sudo wget https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/favicon.ico -P /var/www/html/

