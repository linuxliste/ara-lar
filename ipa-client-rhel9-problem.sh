
yum -y install python3-dnf-plugin-versionlock.noarch

yum -y downgrade ipa-client-4.9.8  python3-cryptography-36.0.1
dnf versionlock add ipa-client  python3-cryptography
