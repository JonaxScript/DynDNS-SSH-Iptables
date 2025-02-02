# 🔐 Dynamic SSH Access Script  

**Automatically manage SSH access rules based on dynamic DNS resolution**  

This script updates **iptables** rules to allow SSH access only from the current IP address of a dynamic DNS host. It enhances security by removing outdated IPs and granting access exclusively to the latest resolved IP.  

## ✨ Features  
✅ Automatically fetches the current IP address of a dynamic DNS host  
✅ Updates **iptables** and **ip6tables** rules for IPv4 and IPv6  
✅ Stores previous IPs to avoid unnecessary rule updates  
✅ Compatible with Linux servers  

## ⚙ Installation & Usage  
### 1️⃣ Download and make the script executable  
```bash
git clone https://github.com/JonaxScript/DynDNS-SSH-Iptables.git
cd DynDNS-SSH-Iptables 
chmod +x dynamic-ssh-access.sh

