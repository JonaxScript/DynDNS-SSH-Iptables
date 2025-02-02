#!/bin/bash
# Name: dynamic-ssh-access
# Description: Automatically manage iptables rules for SSH access based on DNS
# --------------------------
# Configuration (Edit these)
# --------------------------
DYNAMIC_DNS="your-dynamic-dns.example.com"  # Replace with your DNS name
HOSTFILE="/var/lib/ssh-access/current_ips.txt"
SSH_PORT="22"

# --------------------------
# Constants
# --------------------------
IPTABLES="/sbin/iptables"
IP6TABLES="/sbin/ip6tables"
CHAIN_V4="SSH_ACCESS"
CHAIN_V6="SSH_ACCESS6"

# --------------------------
# Functions
# --------------------------

validate_ip() {
  local ip=$1
  # IPv4 validation
  [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && return 0
  # IPv6 validation
  [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]] && return 0
  return 1
}

resolve_ips() {
  # Get IPv4 (A-record)
  local ipv4=$(dig +short "$DYNAMIC_DNS" A 2>/dev/null | \
    grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -n1)

  # Get IPv6 (AAAA-record)
  local ipv6=$(dig +short "$DYNAMIC_DNS" AAAA 2>/dev/null | \
    grep -Eo '([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}' | tail -n1)

  echo "$ipv4 $ipv6"
}

# --------------------------
# Main Script
# --------------------------

# Resolve current IPs
read -r NEW_IPV4 NEW_IPV6 <<< $(resolve_ips)

# Validate at least one IP exists
if [ -z "$NEW_IPV4" ] && [ -z "$NEW_IPV6" ]; then
  echo "Error: No valid IPs found for $DYNAMIC_DNS" >&2
  exit 1
fi

# Load previous IPs
declare -A OLD_IPS
if [ -f "$HOSTFILE" ]; then
  while IFS= read -r line; do
    if [[ $line =~ ^IPv4=(.*) ]]; then
      OLD_IPS["v4"]="${BASH_REMATCH[1]}"
    elif [[ $line =~ ^IPv6=(.*) ]]; then
      OLD_IPS["v6"]="${BASH_REMATCH[1]}"
    fi
  done < "$HOSTFILE"
fi

# Process IPv4 changes
if [ -n "$NEW_IPV4" ]; then
  if ! validate_ip "$NEW_IPV4"; then
    echo "Invalid IPv4: $NEW_IPV4" >&2
    exit 1
  fi

  if [ "${OLD_IPS[v4]}" != "$NEW_IPV4" ]; then
    echo "Updating IPv4 rules for $NEW_IPV4"
    
    # Create chain if missing
    $IPTABLES -N "$CHAIN_V4" 2>/dev/null
    
    # Ensure chain is linked
    if ! $IPTABLES -C INPUT -p tcp --dport "$SSH_PORT" -j "$CHAIN_V4" 2>/dev/null; then
      $IPTABLES -I INPUT 1 -p tcp --dport "$SSH_PORT" -j "$CHAIN_V4"
    fi

    # Update rules
    $IPTABLES -F "$CHAIN_V4"
    $IPTABLES -A "$CHAIN_V4" -s "$NEW_IPV4/32" -p tcp --dport "$SSH_PORT" \
      -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
    $IPTABLES -A "$CHAIN_V4" -p tcp --dport "$SSH_PORT" -j DROP
  fi
fi

# Process IPv6 changes
if [ -n "$NEW_IPV6" ]; then
  if ! validate_ip "$NEW_IPV6"; then
    echo "Invalid IPv6: $NEW_IPV6" >&2
    exit 1
  fi

  if [ "${OLD_IPS[v6]}" != "$NEW_IPV6" ]; then
    echo "Updating IPv6 rules for $NEW_IPV6"
    
    # Create chain if missing
    $IP6TABLES -N "$CHAIN_V6" 2>/dev/null
    
    # Ensure chain is linked
    if ! $IP6TABLES -C INPUT -p tcp --dport "$SSH_PORT" -j "$CHAIN_V6" 2>/dev/null; then
      $IP6TABLES -I INPUT 1 -p tcp --dport "$SSH_PORT" -j "$CHAIN_V6"
    fi

    # Update rules
    $IP6TABLES -F "$CHAIN_V6"
    $IP6TABLES -A "$CHAIN_V6" -s "$NEW_IPV6/128" -p tcp --dport "$SSH_PORT" \
      -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
    $IP6TABLES -A "$CHAIN_V6" -p tcp --dport "$SSH_PORT" -j DROP
  fi
fi

# Store current IPs
mkdir -p "$(dirname "$HOSTFILE")"
> "$HOSTFILE"
[ -n "$NEW_IPV4" ] && echo "IPv4=$NEW_IPV4" >> "$HOSTFILE"
[ -n "$NEW_IPV6" ] && echo "IPv6=$NEW_IPV6" >> "$HOSTFILE"

echo "Rules updated successfully:"
[ -n "$NEW_IPV4" ] && echo "- IPv4: $NEW_IPV4"
[ -n "$NEW_IPV6" ] && echo "- IPv6: $NEW_IPV6"
