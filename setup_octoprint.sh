#!/bin/bash
clear
echo "################################################"
echo "## Script: setup_octoprint.sh"
echo "## By: Andrew Herren"
echo "## Date: 11/13/2014"
echo "# This script is based on instructions that were found at:"
echo "## https://github.com/foosel/OctoPrint/wiki/Setup-on-a-Raspberry-Pi-running-Raspbian"
echo "################################################"

##################variables and settings############
shopt -s nocasematch
install_time=10
start_install="false"
ip=$(hostname --all-ip-addresses)
dir=$(pwd)
echo -e "\nThis script will install Octoprint. If you have any important files or configuration on this SD"
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
		echo "Would you like to install MJPG streamer so that you can setup a webcam with octoprint? (y/n)>"
		read mjpg
#####################################################

###############verify answers########################
		start_install="true"
#####################################################

###############software install/config################
		if [[ "$start_install" = "true" ]]; then
			echo "Starting install. This process normally takes about "$install_time" minutes to complete, however"
       		        echo "this can vary depending on the options chosen and your internet connection. No more input"
               		echo "will be required until the process is complete so feel free to take a walk or grab a drink"
            		echo "of water while you wait. Press enter to continue."
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
		apt-get -q -y install python-pip python-dev git
		apt-get -q -y install python-setuptools
		cd /home/pi
		git clone https://github.com/foosel/OctoPrint.git
		cd OctoPrint
		python setup.py install
		mkdir ~/.octoprint
		usermod -a -G tty pi
		usermod -a -G dialout pi
		if [ "$mjpg" = "y" ] || [ "$mjpg" = "Y" ]; then
			cd ~
			apt-get -q -y install subversion libjpeg8-dev imagemagick libav-tools cmake haproxy
			git clone https://github.com/jacksonliam/mjpg-streamer.git
			cd mjpg-streamer/mjpg-streamer-experimental
			make
			make install
			echo -c "webcam:" >> ~/.octoprint/config.yaml
			echo -e "\tstream: http://"$ip":8080/?action=stream" >> ~/.octoprint/config.yaml
			echo -e "\tffmpeg: /usr/bin/avconv" >> ~/.octoprint/config.yaml

			haproxy_config="/etc/haproxy/haproxy.cfg"
			echo " global" > $haproxy_config
			echo "         maxconn 4096" >> $haproxy_config
			echo "         user haproxy" >> $haproxy_config
			echo "         group haproxy" >> $haproxy_config
			echo "         daemon" >> $haproxy_config
			echo "         log 127.0.0.1 local0 debug" >> $haproxy_config
			echo " " >> $haproxy_config
			echo " defaults" >> $haproxy_config
			echo "         log     global" >> $haproxy_config
			echo "         mode    http" >> $haproxy_config
			echo "         option  httplog" >> $haproxy_config
			echo "         option  dontlognull" >> $haproxy_config
			echo "         retries 3" >> $haproxy_config
			echo "         option redispatch" >> $haproxy_config
			echo "         option http-server-close" >> $haproxy_config
			echo "         option forwardfor" >> $haproxy_config
			echo "         maxconn 2000" >> $haproxy_config
			echo "         timeout connect 5s" >> $haproxy_config
			echo "         timeout client  15min" >> $haproxy_config
			echo "         timeout server  15min" >> $haproxy_config
			echo " " >> $haproxy_config
			echo " frontend public" >> $haproxy_config
			echo "         bind *:80" >> $haproxy_config
			echo "         use_backend webcam if { path_beg /webcam/ }" >> $haproxy_config
			echo "         default_backend octoprint" >> $haproxy_config
			echo " " >> $haproxy_config
			echo " backend octoprint" >> $haproxy_config
			echo "         reqrep ^([^\ :]*)\ /octoprint/(.*)     \1\ /\2" >> $haproxy_config
			echo "         option forwardfor" >> $haproxy_config
			echo "         server octoprint1 127.0.0.1:5000" >> $haproxy_config
			echo " " >> $haproxy_config
			echo " backend webcam" >> $haproxy_config
			echo "         reqrep ^([^\ :]*)\ /webcam/(.*)     \1\ /\2" >> $haproxy_config
			echo "         server webcam1  127.0.0.1:8080" >> $haproxy_config
		fi
		echo "Would you like OctoPrint to start automatically at boot? (y/n) >"
		read answer
		if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
			cp /home/pi/OctoPrint/scripts/octoprint.init /etc/init.d/octoprint
			chmod +x /etc/init.d/octoprint
			cp /home/pi/OctoPrint/scripts/octoprint.default /etc/default/octoprint
			sudo update-rc.d octoprint defaults
		fi
			cd $dir
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
