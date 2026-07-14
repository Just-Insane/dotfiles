#!/usr/bin/env bash
set -euo pipefail

PUBLIC_IFACE=${PUBLIC_IFACE:-$(ip route show default | awk '/default/ {print $5; exit}')}

CF_V4=(
  173.245.48.0/20
  103.21.244.0/22
  103.22.200.0/22
  103.31.4.0/22
  141.101.64.0/18
  108.162.192.0/18
  190.93.240.0/20
  188.114.96.0/20
  197.234.240.0/22
  198.41.128.0/17
  162.158.0.0/15
  104.16.0.0/13
  104.24.0.0/14
  172.64.0.0/13
  131.0.72.0/22
)

CF_V6=(
  2400:cb00::/32
  2606:4700::/32
  2803:f800::/32
  2405:b500::/32
  2405:8100::/32
  2a06:98c0::/29
  2c0f:f248::/32
)

if mapfile -t fetched_v4 < <(curl -fsSL https://www.cloudflare.com/ips-v4) && ((${#fetched_v4[@]} > 0)); then
  CF_V4=("${fetched_v4[@]}")
fi

if mapfile -t fetched_v6 < <(curl -fsSL https://www.cloudflare.com/ips-v6) && ((${#fetched_v6[@]} > 0)); then
  CF_V6=("${fetched_v6[@]}")
fi

iptables -N CF-WEB-INPUT 2>/dev/null || true
iptables -F CF-WEB-INPUT
iptables -A CF-WEB-INPUT -i lo -j RETURN
for cidr in "${CF_V4[@]}"; do
  iptables -A CF-WEB-INPUT -p tcp -m multiport --dports 80,443 -s "$cidr" -j RETURN
  iptables -A CF-WEB-INPUT -p udp --dport 443 -s "$cidr" -j RETURN
done
iptables -A CF-WEB-INPUT -p tcp -m multiport --dports 80,443 -j DROP
iptables -A CF-WEB-INPUT -p udp --dport 443 -j DROP
iptables -A CF-WEB-INPUT -j RETURN
iptables -C INPUT -j CF-WEB-INPUT 2>/dev/null || iptables -I INPUT 1 -j CF-WEB-INPUT

ip6tables -N CF-WEB-INPUT 2>/dev/null || true
ip6tables -F CF-WEB-INPUT
ip6tables -A CF-WEB-INPUT -i lo -j RETURN
for cidr in "${CF_V6[@]}"; do
  ip6tables -A CF-WEB-INPUT -p tcp -m multiport --dports 80,443 -s "$cidr" -j RETURN
  ip6tables -A CF-WEB-INPUT -p udp --dport 443 -s "$cidr" -j RETURN
done
ip6tables -A CF-WEB-INPUT -p tcp -m multiport --dports 80,443 -j DROP
ip6tables -A CF-WEB-INPUT -p udp --dport 443 -j DROP
ip6tables -A CF-WEB-INPUT -j RETURN
ip6tables -C INPUT -j CF-WEB-INPUT 2>/dev/null || ip6tables -I INPUT 1 -j CF-WEB-INPUT

iptables -N HOST-INGRESS 2>/dev/null || true
iptables -F HOST-INGRESS
iptables -A HOST-INGRESS -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A HOST-INGRESS -i lo -j ACCEPT
iptables -A HOST-INGRESS -p icmp -j ACCEPT
iptables -A HOST-INGRESS -p udp --sport 67 --dport 68 -j ACCEPT
iptables -A HOST-INGRESS -p udp --sport 547 --dport 546 -j ACCEPT
# SSH stays public for Ansible and break-glass recovery. CrowdSec monitors sshd.
iptables -A HOST-INGRESS -p tcp --dport 22 -j ACCEPT
# Permit Docker containers, but never the public interface, to reach CrowdSec.
iptables -A HOST-INGRESS ! -i "$PUBLIC_IFACE" -s 172.16.0.0/12 -p tcp -m multiport --dports 7422,8080 -j ACCEPT
iptables -A HOST-INGRESS -p udp --dport 60000:61000 -j ACCEPT
iptables -A HOST-INGRESS -p tcp -m multiport --dports 80,113,443,5350,7881 -j ACCEPT
iptables -A HOST-INGRESS -p udp -m multiport --dports 443,3479,7882 -j ACCEPT
iptables -A HOST-INGRESS -p udp --dport 30000:30020 -j ACCEPT
iptables -A HOST-INGRESS -j DROP
iptables -C INPUT -j HOST-INGRESS 2>/dev/null || iptables -A INPUT -j HOST-INGRESS
iptables -P INPUT DROP

ip6tables -N HOST-INGRESS 2>/dev/null || true
ip6tables -F HOST-INGRESS
ip6tables -A HOST-INGRESS -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A HOST-INGRESS -i lo -j ACCEPT
ip6tables -A HOST-INGRESS -p ipv6-icmp -j ACCEPT
ip6tables -A HOST-INGRESS -p udp --sport 547 --dport 546 -j ACCEPT
ip6tables -A HOST-INGRESS -p tcp --dport 22 -j ACCEPT
ip6tables -A HOST-INGRESS -p udp --dport 60000:61000 -j ACCEPT
ip6tables -A HOST-INGRESS -p tcp -m multiport --dports 80,113,443,5350,7881 -j ACCEPT
ip6tables -A HOST-INGRESS -p udp -m multiport --dports 443,3479,7882 -j ACCEPT
ip6tables -A HOST-INGRESS -p udp --dport 30000:30020 -j ACCEPT
ip6tables -A HOST-INGRESS -j DROP
ip6tables -C INPUT -j HOST-INGRESS 2>/dev/null || ip6tables -A INPUT -j HOST-INGRESS
ip6tables -P INPUT DROP

iptables -N CF-WEB-LOCKDOWN 2>/dev/null || true
iptables -F CF-WEB-LOCKDOWN
iptables -A CF-WEB-LOCKDOWN ! -i "$PUBLIC_IFACE" -j RETURN
for cidr in "${CF_V4[@]}"; do
  iptables -A CF-WEB-LOCKDOWN -p tcp -m multiport --dports 80,443 -s "$cidr" -j RETURN
  iptables -A CF-WEB-LOCKDOWN -p udp --dport 443 -s "$cidr" -j RETURN
done
iptables -A CF-WEB-LOCKDOWN -p tcp -m multiport --dports 80,443 -j DROP
iptables -A CF-WEB-LOCKDOWN -p udp --dport 443 -j DROP
iptables -A CF-WEB-LOCKDOWN -j RETURN
iptables -C DOCKER-USER -j CF-WEB-LOCKDOWN 2>/dev/null || iptables -I DOCKER-USER 1 -j CF-WEB-LOCKDOWN

ip6tables -N CF-WEB-LOCKDOWN 2>/dev/null || true
ip6tables -F CF-WEB-LOCKDOWN
ip6tables -A CF-WEB-LOCKDOWN ! -i "$PUBLIC_IFACE" -j RETURN
for cidr in "${CF_V6[@]}"; do
  ip6tables -A CF-WEB-LOCKDOWN -p tcp -m multiport --dports 80,443 -s "$cidr" -j RETURN
  ip6tables -A CF-WEB-LOCKDOWN -p udp --dport 443 -s "$cidr" -j RETURN
done
ip6tables -A CF-WEB-LOCKDOWN -p tcp -m multiport --dports 80,443 -j DROP
ip6tables -A CF-WEB-LOCKDOWN -p udp --dport 443 -j DROP
ip6tables -A CF-WEB-LOCKDOWN -j RETURN
ip6tables -C DOCKER-USER -j CF-WEB-LOCKDOWN 2>/dev/null || ip6tables -I DOCKER-USER 1 -j CF-WEB-LOCKDOWN
