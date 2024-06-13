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

# Allow SSH connections
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP, HTTPS, and SSH outbound connections
sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

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
