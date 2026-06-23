# Switch to root privileges
sudo su -
# Update system packages
apt update && apt upgrade -y
# Download and execute the official K3s installation script
curl -sfL https://get.k3s.io | sh -
# Verify that the K3s service is active and running
systemctl status k3s
kubectl get nodes
