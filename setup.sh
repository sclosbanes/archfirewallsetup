#!/bin/bash

# Clear the screen for a full-screen view
clear

# Display a welcome message
echo "##############################################"
echo "#        Arch Linux Firewall Setup           #"
echo "##############################################"
echo ""

# Display the current network interfaces
echo "Detecting network interfaces..."
INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')
echo "Available interfaces:"
echo "$INTERFACES"
echo ""

# Prompt the user to select the WAN interface
echo "Please enter the WAN interface (e.g., eth0, wlan0):"
read -r WAN

# Validate the WAN interface
while ! echo "$INTERFACES" | grep -qw "$WAN"; do
    echo "Invalid interface. Please enter a valid WAN interface:"
    read -r WAN
done

# Prompt the user to select the LAN interface
echo "Please enter the LAN interface (e.g., eth1, wlan1):"
read -r LAN

# Validate the LAN interface
while ! echo "$INTERFACES" | grep -qw "$LAN"; do
    echo "Invalid interface. Please enter a valid LAN interface:"
    read -r LAN
done

# Display the selected interfaces
echo ""
echo "Configuring firewall with the following interfaces:"
echo "WAN: $WAN"
echo "LAN: $LAN"
echo ""

# Flush current rules
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -F

# Allow loopback interface
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Allow established and related connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH inbound connections
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP, HTTPS, and SSH outbound connections
sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
###################################################
##########-------------START-SCL-------############
# Prompt the user to enter the IP address to allow traffic from
echo "Please enter the IP address to allow outbound traffic from:"
read -r IP_ADDRESS

# Validate the IP address
if [[ ! $IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid IP address. Please enter a valid IP address."
    exit 1
fi

# Allow outbound traffic from the specified IP address
sudo iptables -A OUTPUT -d 0.0.0.0/0 -s "$IP_ADDRESS" -j ACCEPT
############-------------SCL-END------##################
########################################################
# Allow ping
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
sudo iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

# Default policies
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT DROP

# Enable IP Forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Enable NAT for LAN traffic
sudo iptables -t nat -A POSTROUTING -o "$WAN" -j MASQUERADE

# Forward traffic from LAN to WAN
sudo iptables -A FORWARD -i "$LAN" -o "$WAN" -j ACCEPT
sudo iptables -A FORWARD -i "$WAN" -o "$LAN" -m state --state RELATED,ESTABLISHED -j ACCEPT

####################SIDNEY#MODIFICATIONS#START##############################################
# Block packets with Bogus TCP flags
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN FIN,SYN -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,ACK FIN -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,URG URG -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL ALL -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL FIN,PSH,URG -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j LOG --log-prefix "Bogus_TCP_flags:"
sudo iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j LOG --log-prefix "Bogus_TCP_flags:"

# Block ping of death
sudo iptables -A INPUT -p tcp -m connlimit --connlimit-above 66 -j LOG --log-prefix "Ping_of_Death:"
sudo iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j ACCEPT 
sudo iptables -A INPUT -p tcp -m conntrack --ctstate NEW -j LOG --log-prefix "New_Connection:"
sudo iptables -t mangle -A PREROUTING -f -j LOG --log-prefix "Fragmented_Packets:"
sudo iptables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j ACCEPT 
sudo iptables -A INPUT -p tcp --tcp-flags RST RST -j LOG --log-prefix "RST_Packets:"

# Set IP rules prevent stealth scans and port scans
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j LOG --log-prefix "Stealth_Scan:"
iptables -A INPUT -p tcp --tcp-flags ALL FIN -j LOG --log-prefix "Stealth_Scan:"
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "Stealth_Scan:"
iptables -A INPUT -p tcp --tcp-flags ALL URG,PSH,SYN,FIN -j LOG --log-prefix "Stealth_Scan:"
iptables -A INPUT -p tcp --tcp-flags ALL SYN,FIN -j LOG --log-prefix "Stealth_Scan:"
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j LOG --log-prefix "Stealth_Scan:"
iptables -A INPUT -p tcp --tcp-flags ALL RST -j LOG --log-prefix "Stealth_Scan:"

# Block invalid packets and log them
sudo iptables -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j LOG --log-prefix "sidney_Invalid_Packets: "
sudo iptables -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP

# Block new packets that are not SYN and log them
sudo iptables -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j LOG --log-prefix "sidney_Non_SYN_Packets: "
sudo iptables -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP

# Block uncommon MSS values and log them
sudo iptables -t mangle -A PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss 536:65535 -j LOG --log-prefix "sidney_Uncommon_MSS_Values: "
sudo iptables -t mangle -A PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss 536:65535 -j DROP

#TO CHECK THIS RULES ABOVE YOU JUST TYPE THIS SAMPLE COMMAND sudo grep "Bogus_TCP_flags" /var/log/syslog
##################SIDNEY#MODIFICATION#END##########################################################

# Display completion message
clear
echo "##############################################"
echo "#        Firewall Configuration Complete     #"
echo "##############################################"
echo ""
echo "WAN Interface: $WAN"
echo "LAN Interface: $LAN"
echo ""
echo "Firewall rules have been successfully applied."
echo ""
