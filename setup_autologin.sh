#!/bin/bash
user=pi
screen_name=raspberry
apt-get install -q -y screen
mv /etc/inittab /etc/inittab.old
awk -v user="$user" '{
	if($0~/1:2345:respawn:\/sbin\/getty/){
		print "#"$0"\n1:2345:respawn:/bin/login -f "user" tty1 </dev/tty1 >/dev/tty1 2>&1";
	}else{
		print $0;
	}}' /etc/inittab.old > /etc/inittab
echo -e "\nrasscreen=\$(screen -ls | grep $screen_name)" >> /home/$user/.profile
echo "if [[ \$rasscreen == \"\" ]]; then" >> /home/$user/.profile
echo -e "\tscreen -S $screen_name" >> /home/$user/.profile
echo "fi" >> /home/$user/.profile
echo "alias fp='screen -x $screen_name'" >> /home/$user/.bashrc

