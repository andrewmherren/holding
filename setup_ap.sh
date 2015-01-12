#!/bin/bash
clear
echo "################################################"
echo "## Script: setup_ap.sh"
echo "## By: Andrew Herren"
echo "## Date: 1/4/2015"
echo "## Script instructions:"
echo "## Based on a tutorial found at: elinux.org/RPI-Wireless-Hotspot"
echo "################################################"

##################variables and settings############
shopt -s nocasematch
install_time=10
start_install="true"
dir=$(pwd)
echo -e "\nThis script will setup a wifi network with a DHCP server. If you have any important files or configuration on this SD"
echo "card, you should exit now and make a backup in case anything goes wrong during the installation. "
echo "Would you like to continue? (y/n) >"
read answer
####################################################

################questions in the beinging############
case "$answer" in
y|yes )
	if [[ "$(whoami)" = "root" ]]; then
		echo "Would you like to update the sources list before continuing? (y/n)>"
		read sources
		echo "Would you like to perform a dist-upgrade before continuing? (y/n)>"
		read upgr
		echo "Would you like to perform autoremove to get rid of old/unused packages before continuing? (y/n)>"
		read autor
		echo "What would you like the name (SSID) of your wireless network to be? >"
		read ssid
		echo "What would you like the wpa password of yoru wireless network to be? >"
		read wpa_pass
		echo "Do you want your AP to automatically start when your pi boots? (y/n) >"
		read autostart
		echo "Do you want to start your new AP when the script finishes? (y/n) >"
		read startWhenDone
		echo "Do you want to create aliases \"APup\" and \"APdown\" to start and"
		echo "stop hostapd and udhcpd? (y/n) >"
		read makealiases
		echo "Do you want to create aliases \"hideAP\" and \"showAP\" to turn on"
		echo "and off broadcasting of your AP's SSID? (y/n) >"
		read makealiases2
#####################################################

###############verify answers########################
#####################################################

###############software install/config################
		if [[ "$start_install" = "true" ]]; then
			echo "Starting install. This process normally takes about "$install_time" minutes to complete, however"
       		        echo "this can vary depending on the options chosen and your internet connection. No more input"
               		echo "will be required until the process is complete so you may want to go do something else for a bit."
            		echo "Press enter to continue."
              		read garbage
			case "$sources" in
			y | yes )
				echo "Performing update to sources list..."
				apt-get -q -y update
				;;
			* )
				echo "Skipping update to sources list..."
				;;
			esac
			case "$upgr" in
			y | yes)
				echo "Performing dist-upgrade..."
				apt-get -q -y dist-upgrade
				;;
			* )
				echo "Skipping dist-upgrade..."
				;;
			esac
			case "$autor" in
			y | yes )
				echo "Performing autoremove..."
				apt-get -q -y autoremove
				;;
			* )
				echo "Skipping autremove..."
				;;
			esac
			apt-get -q -y install hostapd udhcpd
			mv /etc/udhcpd.conf /etc/udhcpd.conf.old
			echo "start 192.168.42.2 #range of ips to give to clients" > /etc/udhcpd.conf
			echo "end 192.168.42.20" >> /etc/udhcpd.conf
			echo "interface wlan0 #defice to listen on" >> /etc/udhcpd.conf
			echo "remaining yes" >> /etc/udhcpd.conf
			echo "opt dns 8.8.8.8 8.8.4.4 #googles free dns servers" >> /etc/udhcpd.conf
			echo "opt subnet 255.255.255.0" >> /etc/udhcpd.conf
			echo "opt router 192.168.42.1 #pis ip on wlan0" >> /etc/udhcpd.conf
			echo "opt lease 864000 #10 day dhcp lease" >> /etc/udhcpd.conf
			mv /etc/default/udhcpd /etc/default/udhcpd.old
			awk '{
				if($1~/DHCPD_ENABLED/){
					print "#"$0;
				}else{
					print $0;
				}}' /etc/default/udhcpd.old > /etc/default/udhcpd

			ifdown wlan0
			mv /etc/network/interfaces /etc/network/interfaces.old
			echo -e "auto lo\n" > /etc/network/interfaces
			echo "iface lo inet loopback" >> /etc/network/interfaces
			echo -e "iface eth0 inet dhcp\n" >> /etc/network/interfaces
			echo -e "allow -hotplug wlan0\n" >> /etc/network/interfaces
			echo "iface wlan0 inet static" >> /etc/network/interfaces
			echo "address 192.168.42.1" >> /etc/network/interfaces
			echo "netmask 255.255.255.0" >> /etc/network/interfaces
			ifconfig wlan0 192.168.42.1
			
			echo "interface=wlan0" > /etc/hostapd/hostapd.conf
			echo "driver=nl80211" >> /etc/hostapd/hostapd.conf
			echo "ssid=$ssid" >> /etc/hostapd/hostapd.conf
			echo "hw_mode=g" >> /etc/hostapd/hostapd.conf
			echo "channel=6" >> /etc/hostapd/hostapd.conf
			echo "macaddr_acl=0" >> /etc/hostapd/hostapd.conf
			echo "auth_algs=1" >> /etc/hostapd/hostapd.conf
			echo "ignore_broadcast_ssid=0" >> /etc/hostapd/hostapd.conf
			echo "wpa=2" >> /etc/hostapd/hostapd.conf
			echo "wpa_passphrase=$wpa_pass" >> /etc/hostapd/hostapd.conf
			echo "wpa_key_mgmt=WPA-PSK" >> /etc/hostapd/hostapd.conf
			echo "wpa_pairwise=TKIP" >> /etc/hostapd/hostapd.conf
			echo "rsn_pairwise=CCMP" >> /etc/hostapd/hostapd.conf
			echo "ctrl_interface=/var/run/hostapd" >> /etc/hostapd/hostapd.conf

			mv /etc/default/hostapd /etc/default/hostapd.old
			awk '{
				if($1~/DAEMON_CONF/){
					print "DAEMON_CONF=\"/etc/hostapd/hostapd.conf\"";
				}else{
					print $0;
				}}' /etc/default/hostapd.old > /etc/default/hostapd
			echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
			
			iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
			iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
			iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
			iptables-save > /etc/iptables.ipv4.nat

			echo -e "\nup iptables-restore < /etc/iptables.ipv4.nat" >> /etc/network/interfaces
			echo "Updated /etc/network/interfaces"

			case "$startWhenDone" in
			y|yes )
				service hostapd start
				service udhcpd start
				;;
			* )
				;;
			esac
			case "$autostart" in
			y|yes )
				update-rc.d hostapd enable
				update-rc.d udhcpd enable
				;;
			* )
				;;
			esac
			if [[ $(grep "alias sudo" /etc/profile) == "" ]]; then
				echo "#alias sudo with a trailing space to allow sudoing aliases" >> /etc/profile
				echo "alias sudo='sudo '" >> /etc/profile
			fi
			case "$makealiases" in
			y|yes )
				echo -e "\n#Access point aliases" >> /etc/profile
				echo "alias APup='service hostapd start; service udhcpd start'" >> /etc/profile
				echo "alias APdown='service hostapd stop service udhcpd stop'" >> /etc/profile
				;;
			* )
				;;
			esac
			case "$makealiases2" in
			y|yes )
				echo "#!/bin/bash" > /etc/hostapd/hideAP.sh
				echo "case \"\$1\" in" >> /etc/hostapd/hideAP.sh
				echo "1)" >> /etc/hostapd/hideAP.sh
				echo -e "\ttmp='1'" >> /etc/hostapd/hideAP.sh
				echo -e "\t;;" >> /etc/hostapd/hideAP.sh
				echo "0)" >> /etc/hostapd/hideAP.sh
				echo -e "\ttmp='0'" >> /etc/hostapd/hideAP.sh
				echo -e "\t;;" >> /etc/hostapd/hideAP.sh
				echo "*)" >> /etc/hostapd/hideAP.sh
				echo -e "\techo \"Invalid arg. Only 1 or 0 allowed\"" >> /etc/hostapd/hideAP.sh
				echo "esac" >> /etc/hostapd/hideAP.sh
				echo "if [[ \$tmp == '0' || \$tmp == '1' ]]; then" >> /etc/hostapd/hideAP.sh
				echo -e "\tif [[ \$(whoami) == \"root\" ]]; then" >> /etc/hostapd/hideAP.sh
				echo -e "\t\tmv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.tmp" >> /etc/hostapd/hideAP.sh
				echo -e "\t\tawk -v val=\"\$tmp\" '{if(\$0~/ignore_broadcast_ssid/){print \"ignore_broadcast_ssid=\"val;}else{print \$0}}' /etc/hostapd/hostapd.tmp > /etc/hostapd/hostapd.conf" >> /etc/hostapd/hideAP.sh
				echo -e "\t\trm /etc/hostapd/hostapd.tmp" >> /etc/hostapd/hideAP.sh
				echo -e "\telse" >> /etc/hostapd/hideAP.sh
				echo -e "\t\techo \"Must be root. Try again with sudo.\"" >> /etc/hostapd/hideAP.sh
				echo -e "\tfi" >> /etc/hostapd/hideAP.sh
				echo "fi" >> /etc/hostapd/hideAP.sh
				chmod +x /etc/hostapd/hideAP.sh
	
				echo "" >> /etc/profile
				echo "alias hideAP='/etc/hostapd/hideAP.sh 1'" >> /etc/profile
				echo "alias showAP='/etc/hostapd/hideAP.sh 0'" >> /etc/profile
				;;
			* )
				;;
			esac
			cd $dir
			echo "Install complete!"
		fi
	else
		echo "This script must be run as root. Please try again using sudo."
	fi
	;;
* )
	echo "Exiting without changes."
	;;
esac
shopt -u nocasematch
