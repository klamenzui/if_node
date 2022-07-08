telegraf_name=<your node name>
main_url="http://<your ip>:<your port>"
telegraf_user=<telegraf user name>
telegraf_pass=<telegraf password>
user=<your user>
root_path=/$user


echo "install telegraf"
cat <<EOF | sudo tee /etc/apt/sources.list.d/influxdata.list
deb https://repos.influxdata.com/ubuntu bionic stable
EOF
sudo curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install telegraf jq bc
sudo systemctl enable --now telegraf
sudo systemctl is-enabled telegraf
sudo adduser telegraf sudo
sudo adduser telegraf adm
sudo -- bash -c 'echo "telegraf ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers'
sudo cp /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.orig
sudo rm -rf /etc/telegraf/telegraf.conf
wget https://raw.githubusercontent.com/klamenzui/if_node/main/monitoring/telegraf.txt -O /etc/telegraf/telegraf.conf
sed -i "s#%telegraf_name%#$telegraf_name#g" /etc/telegraf/telegraf.conf
sed -i "s#%main_url%#$main_url#g" /etc/telegraf/telegraf.conf
sed -i "s#%telegraf_user%#$telegraf_user#g" /etc/telegraf/telegraf.conf
sed -i "s#%telegraf_pass%#$telegraf_pass#g" /etc/telegraf/telegraf.conf
sed -i "s#%root_path%#$root_path#g" /etc/telegraf/telegraf.conf
sed -i "s#%user%#$user#g" /etc/telegraf/telegraf.conf
mkdir -p $root_path/monitoring
wget https://raw.githubusercontent.com/klamenzui/if_node/main/monitoring/monitor.sh -O $root_path/monitoring/monitor.sh
chmod +x $root_path/monitoring/monitor.sh
systemctl start telegraf