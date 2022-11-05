#!/bin/bash
clear

GREEN="\033[32m"
echo -e "${GREEN}============= Selamat Datang di Quick Install LSP 2022 ================\033[0m\n"
sleep 1

# Konfigurasi IP Address
echo "======= STEP 1 - KONFIGURASI NETWORK DEBIAN ========"
sleep 2
read -p "Masukkan IP Debian Anda (contoh: 192.168.1.2): " ipDebian
read -p "Masukkan IP Gateway (contoh: 192.168.1.1): " ipGateway
echo -e "Sedang mengkonfigurasi network dimohon tunggu..."
echo "
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp0s3
iface enp0s3 inet static
    address "$ipDebian"/24
    gateway "$ipGateway"
" > /etc/network/interfaces
systemctl restart networking
echo -e "Konfigurasi network telah selesai!\n"

# Repository
read -p "Apakah anda ingin memperbarui repository?(y/n): " repo
case $repo in
    "y")
        versiDebian=$(cat /etc/debian_version | awk -F '.' '{print $1}')
        case $versiDebian in
            '10')
                echo "Sedang memperbarui repository dimohon tunggu..."
                echo "
deb http://repo.antix.or.id/debian/ buster main contrib non-free
deb http://repo.antix.or.id/debian/ buster-updates main contrib non-free
deb http://repo.antix.or.id/debian-security/ buster/updates main contrib non-free" > /etc/apt/sources.list
                echo "Sedang mengupdate repository dimohon tunggu..."
                apt-get update -qq
                echo -e "\nUpdate repository telah selesai!\n"
            ;;
            '11')
                echo "Sedang memperbarui repository dimohon tunggu..."
                echo "
deb http://repo.antix.or.id/debian/ bullseye main contrib non-free
deb http://repo.antix.or.id/debian/ bullseye-updates main contrib non-free
deb http://repo.antix.or.id/debian-security/ bullseye-security main contrib non-free" > /etc/apt/sources.list
                echo "Sedang mengupdate repository dimohon tunggu..."
                apt-get update -qq
                echo -e "\nUpdate repository telah selesai!\n"
            ;;
            *)
                echo -e "Oke, lanjut ke tahap berikutnya!\n"
            ;;
        esac
    ;;
    "n")
        echo -e "Oke, lanjut ke tahap berikutnya!\n"
    ;;
    *)
        echo -e "Oke, lanjut ke tahap berikutnya!\n"
    ;;
esac

# Konfigurasi DNS Server
read -p "Masukkan IP CCTV (contoh: 192.168.1.1): " ipCCTV
read -p "Masukkan IP VoIP (contoh: 192.168.1.1): " ipVoIP
ptrIP=$(echo $ipDebian | awk -F. '{print $4"."$3"."$2"."$1}' | cut -d '.' -f 1)
ptrIpcctv=$(echo $ipCCTV | awk -F. '{print $4"."$3"."$2"."$1}' | cut -d '.' -f 1)
ptrIpvoip=$(echo $ipVoIP | awk -F. '{print $4"."$3"."$2"."$1}' | cut -d '.' -f 1)
revIP=$(echo $ipDebian | awk -F. '{print $4"."$3"."$2"."$1}' | cut -d '.' -f 2-4)

echo -e "\n======= STEP 2 - KONFIGURASI DNS SERVER ========"
sleep 1
echo -e "Sedang melakukan instalasi paket-paket DNS Server dimohon tunggu...\n"
apt-get install -qq -y bind9 dnsutils resolvconf
echo -e "\nInstalasi selesai!\n"
read -p "Masukkan nama file database forward (contoh: db.<nama>): " dbForward
read -p "Masukkan nama file database reverse (contoh: db.<ip>): " dbReverse
read -p "Masukkan nama domain yang ingin dibuat (contoh: <nis>.net): " namaDomain
echo -e "Mohon tunggu, sedang melakukan konfigurasi DNS Server...\n"
cp /etc/bind/db.local /etc/bind/$dbForward
cp /etc/bind/db.127 /etc/bind/$dbReverse
echo -e "
;
; BIND data file for local loopback interface
;
\$TTL    604800
@       IN      SOA     "$namaDomain". root."$namaDomain". (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      "$namaDomain".
@       IN      A       "$ipDebian"
www     IN      A       "$ipDebian"
mail    IN      A       "$ipDebian"
cacti   IN      A       "$ipDebian"
cctv    IN      A       "$ipCCTV"
voip    IN      A       "$ipVoIP"
"$namaDomain"    IN      MX  10   mail" > /etc/bind/$dbForward
echo -e "
;
; BIND reverse data file for local loopback interface
;
\$TTL    604800
@       IN      SOA     "$namaDomain". root."$namaDomain". (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      "$namaDomain".
"$ptrIP"   IN      PTR     "$namaDomain".
"$ptrIP"   IN      PTR     www."$namaDomain".
"$ptrIP"   IN      PTR     mail."$namaDomain".
"$ptrIP"   IN      PTR     cacti."$namaDomain".
"$ptrIpcctv"   IN     PTR     cctv."$namaDomain".
"$ptrIpvoip"   IN     PTR     voip."$namaDomain"." > /etc/bind/$dbReverse
echo '
zone "'$namaDomain'" {
      type master;
      file "/etc/bind/'$dbForward'";

};

zone "'$revIP'.in-addr.arpa" {
      type master;
      file "/etc/bind/'$dbReverse'";
};' > /etc/bind/named.conf.local
echo -e '
options {
        directory "/var/cache/bind";

        // If there is a firewall between you and nameservers you want
        // to talk to, you may need to fix the firewall to allow multiple
        // ports to talk.  See http://www.kb.cert.org/vuls/id/800113

        // If your ISP provided one or more IP addresses for stable
        // nameservers, you probably want to use them as forwarders.
        // Uncomment the following block, and insert the addresses replacing
        // the all-0'\''s placeholder.

        forwarders {
          8.8.8.8;
        };

        //========================================================================
        // If BIND logs error messages about the root key being expired,
        // you will need to update your keys.  See https://www.isc.org/bind-keys
        //========================================================================
        dnssec-validation no;
        allow-query {any;};
        allow-recursion {any;};
        listen-on {any;};
        listen-on-v6 { any; };
};' > /etc/bind/named.conf.options

systemctl restart bind9
systemctl enable -q resolvconf

echo '
# Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
# 127.0.0.53 is the systemd-resolved stub resolver.
# run "resolvectl status" to see details about the actual nameservers.

nameserver '$ipDebian'' > /etc/resolvconf/resolv.conf.d/head

resolvconf -u

echo -e "Konfigurasi DNS Server telah selesai!\n"

echo -e "======= STEP 3 - INSTALASI & KONFIGURASI LAMP ======="
sleep 1
echo -e "Sedang menginstall & konfigurasi paket-paket untuk LAMP, dimohon tunggu...\n"
apt-get install -qq -y apache2 libapache2-mod-php php php-mysql php-xml php-mbstring php-cgi mariadb-server mariadb-client

checkWp=$(ls /var/www/ | grep wordpress)
checkPma=$(ls /var/www/ | grep phpmyadmin)
if [[ ! $checkWp && ! $checkPma ]];
then
    wget -q https://files.phpmyadmin.net/phpMyAdmin/5.2.0/phpMyAdmin-5.2.0-all-languages.tar.gz
    wget -q https://wordpress.org/wordpress-6.0.3.tar.gz
    tar -zxf phpMyAdmin-5.2.0-all-languages.tar.gz
    tar -zxf wordpress-6.0.3.tar.gz
    mv phpMyAdmin-5.2.0-all-languages /var/www/phpmyadmin
    mv wordpress /var/www/
fi

cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/mail.conf
cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/pma.conf
cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/cacti.conf

checkVarLib=$(cat /etc/apache2/apache2.conf | grep "<Directory /var/lib/>")
if [[ ! $checkVarLib ]];
then
echo "
<Directory /var/lib/>
      Options -Indexes +FollowSymLinks
      AllowOverride All
      Require all granted
</Directory>" >> /etc/apache2/apache2.conf
fi

echo -e "
<VirtualHost *:80>
        # The ServerName directive sets the request scheme, hostname and port that
        # the server uses to identify itself. This is used when creating
        # redirection URLs. In the context of virtual hosts, the ServerName
        # specifies what hostname must appear in the request's Host: header to
        # match this virtual host. For the default virtual host (this file) this
        # value is not decisive as it is used as a last resort host regardless.
        # However, you must set it for any further virtual host explicitly.
        ServerName www."$namaDomain"
        ServerAlias "$namaDomain"
        ServerAdmin webmaster@"$namaDomain"
        DocumentRoot /var/www/wordpress/
        Alias /phpmyadmin /var/www/phpmyadmin/

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined

        # For most configuration files from conf-available/, which are
        # enabled or disabled at a global level, it is possible to
        # include a line for only one particular virtual host. For example the
        # following line enables the CGI configuration for this host only
        # after it has been globally disabled with ""a2disconf"".
        #Include conf-available/serve-cgi-bin.conf
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet" > /etc/apache2/sites-available/www.conf
echo -e "
<VirtualHost *:80>
        # The ServerName directive sets the request scheme, hostname and port that
        # the server uses to identify itself. This is used when creating
        # redirection URLs. In the context of virtual hosts, the ServerName
        # specifies what hostname must appear in the request's Host: header to
        # match this virtual host. For the default virtual host (this file) this
        # value is not decisive as it is used as a last resort host regardless.
        # However, you must set it for any further virtual host explicitly.
        ServerName mail."$namaDomain"

        ServerAdmin webmaster@"$namaDomain"
        DocumentRoot /var/lib/roundcube/

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined

        # For most configuration files from conf-available/, which are
        # enabled or disabled at a global level, it is possible to
        # include a line for only one particular virtual host. For example the
        # following line enables the CGI configuration for this host only
        # after it has been globally disabled with ""a2disconf"".
        #Include conf-available/serve-cgi-bin.conf
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet" > /etc/apache2/sites-available/mail.conf
echo -e "
<VirtualHost *:80>
        # The ServerName directive sets the request scheme, hostname and port that
        # the server uses to identify itself. This is used when creating
        # redirection URLs. In the context of virtual hosts, the ServerName
        # specifies what hostname must appear in the request's Host: header to
        # match this virtual host. For the default virtual host (this file) this
        # value is not decisive as it is used as a last resort host regardless.
        # However, you must set it for any further virtual host explicitly.
        ServerName cacti."$namaDomain"

        ServerAdmin webmaster@"$namaDomain"
        DocumentRoot /usr/share/cacti/site

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined

        # For most configuration files from conf-available/, which are
        # enabled or disabled at a global level, it is possible to
        # include a line for only one particular virtual host. For example the
        # following line enables the CGI configuration for this host only
        # after it has been globally disabled with ""a2disconf"".
        #Include conf-available/serve-cgi-bin.conf
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet" > /etc/apache2/sites-available/cacti.conf

a2ensite mail.conf www.conf cacti.conf > /dev/null
a2dissite 000-default.conf > /dev/null
systemctl restart apache2

cp /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php
cp /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php

echo ""
read -p "Masukkan nama database untuk wordpress: " namaDb
read -p "Masukkan nama user untuk database (contoh: yasin): " userDb
read -p "Masukkan password untuk nama user database: " passDb
read -p "Masukkan password konfirmasi untuk nama user database: " passDbConfirm

if [ $passDb == $passDbConfirm ];
then
echo "create database if not exists phpmyadmin;
grant all privileges on *.* to '"$userDb"'@'localhost' identified by '"$passDb"' with grant option;
grant all privileges on phpmyadmin.* to 'pma'@'localhost' identified by '1';" > pma.sql
else
    while [ $passDb != $passDbConfirm ]
    do
        echo "Konfirmasi Password tidak sama dengan password yang diinputkan!"
        read -p "Masukkan password untuk nama user database: " passDb
        read -p "Masukkan password konfirmasi untuk nama user database: " passDbConfirm
    done
fi

chown -R www-data:www-data /var/www/wordpress
chown -R www-data:www-data /var/www/phpmyadmin

mysql -e "create database if not exists "$namaDb";"
mysql -s < pma.sql
mysql -s phpmyadmin < /var/www/phpmyadmin/sql/create_tables.sql

sed -i "s/\$cfg\['blowfish_secret'\] = ''\;/\$cfg\['blowfish_secret'\] = 'adsJ*##@FJJGngfgjH32432ngfndgi#\$gbgbgs'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['controlhost'\] = ''\;/\$cfg\['Servers'\]\[\$i\]\['controlhost'\] = 'localhost'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['controlport'\] = ''\;/\$cfg\['Servers'\]\[\$i\]\['controlport'\] = '3306'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['controluser'\] = 'pma'\;/\$cfg\['Servers'\]\[\$i\]\['controluser'\] = 'pma'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['controlpass'\] = 'pmapass'\;/\$cfg\['Servers'\]\[\$i\]\['controlpass'\] = '1'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['pmadb'\] = 'phpmyadmin'\;/\$cfg\['Servers'\]\[\$i\]\['pmadb'\] = 'phpmyadmin'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['bookmarktable'\] = 'pma__bookmark'\;/\$cfg\['Servers'\]\[\$i\]\['bookmarktable'\] = 'pma__bookmark'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['relation'\] = 'pma__relation'\;/\$cfg\['Servers'\]\[\$i\]\['relation'\] = 'pma__relation'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['table_info'\] = 'pma__table_info'\;/\$cfg\['Servers'\]\[\$i\]\['table_info'\] = 'pma__table_info'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['table_coords'\] = 'pma__table_coords'\;/\$cfg\['Servers'\]\[\$i\]\['table_coords'\] = 'pma__table_coords'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['pdf_pages'\] = 'pma__pdf_pages'\;/\$cfg\['Servers'\]\[\$i\]\['pdf_pages'\] = 'pma__pdf_pages'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['column_info'\] = 'pma__column_info'\;/\$cfg\['Servers'\]\[\$i\]\['column_info'\] = 'pma__column_info'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['history'\] = 'pma__history'\;/\$cfg\['Servers'\]\[\$i\]\['history'\] = 'pma__history'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['table_uiprefs'\] = 'pma__table_uiprefs'\;/\$cfg\['Servers'\]\[\$i\]\['table_uiprefs'\] = 'pma__table_uiprefs'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['tracking'\] = 'pma__tracking'\;/\$cfg\['Servers'\]\[\$i\]\['tracking'\] = 'pma__tracking'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['userconfig'\] = 'pma__userconfig'\;/\$cfg\['Servers'\]\[\$i\]\['userconfig'\] = 'pma__userconfig'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['recent'\] = 'pma__recent'\;/\$cfg\['Servers'\]\[\$i\]\['recent'\] = 'pma__recent'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['favorite'\] = 'pma__favorite'\;/\$cfg\['Servers'\]\[\$i\]\['favorite'\] = 'pma__favorite'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['users'\] = 'pma__users'\;/\$cfg\['Servers'\]\[\$i\]\['users'\] = 'pma__users'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['usergroups'\] = 'pma__usergroups'\;/\$cfg\['Servers'\]\[\$i\]\['usergroups'\] = 'pma__usergroups'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['navigationhiding'\] = 'pma__navigationhiding'\;/\$cfg\['Servers'\]\[\$i\]\['navigationhiding'\] = 'pma__navigationhiding'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['savedsearches'\] = 'pma__savedsearches'\;/\$cfg\['Servers'\]\[\$i\]\['savedsearches'\] = 'pma__savedsearches'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['central_columns'\] = 'pma__central_columns'\;/\$cfg\['Servers'\]\[\$i\]\['central_columns'\] = 'pma__central_columns'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['designer_settings'\] = 'pma__designer_settings'\;/\$cfg\['Servers'\]\[\$i\]\['designer_settings'\] = 'pma__designer_settings'\;/" /var/www/phpmyadmin/config.inc.php
sed -i "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['export_templates'\] = 'pma__export_templates'\;/\$cfg\['Servers'\]\[\$i\]\['export_templates'\] = 'pma__export_templates'\;/" /var/www/phpmyadmin/config.inc.php

sed -i "s/define( 'DB_NAME', 'database_name_here' )\;/define( 'DB_NAME', '$namaDb' )\;/" /var/www/wordpress/wp-config.php
sed -i "s/define( 'DB_USER', 'username_here' )\;/define( 'DB_USER', '$userDb' )\;/" /var/www/wordpress/wp-config.php
sed -i "s/define( 'DB_PASSWORD', 'password_here' )\;/define( 'DB_PASSWORD', '$passDb' )\;/" /var/www/wordpress/wp-config.php

echo -e "\nInstalasi & konfigurasi paket-paket LAMP telah selesai!\n"

echo -e "======= STEP 4 - INSTALASI & KONFIGURASI MAIL ========\n"
echo "Sedang melakukan instalasi & konfigurasi mail server..."
apt-get install -qq -y postfix dovecot-imapd dovecot-pop3d roundcube

$maildir=$(cat /etc/postfix/main.cf | grep "home_mailbox")
if [[ ! $maildir ]];
then
echo "home_mailbox = Maildir/" >> /etc/postfix/main.cf
fi

read -p "Tambahkan user pertama untuk mail: " userMail1
read -p "Masukkan password untuk user pertama: " passMail1
read -p "Tambahkan user kedua untuk mail: " userMail2
read -p "Masukkan password untuk user kedua: " passMail2

useradd -m $userMail1
useradd -m $userMail2

echo -e "$passMail1\n$passMail1" | passwd $userMail1
echo -e "$passMail2\n$passMail2" | passwd $userMail2

maildirmake.dovecot /etc/skel/Maildir

sed -i "s/\#disable_plaintext_auth = yes/disable_plaintext_auth = yes/" /etc/dovecot/conf.d/10-auth.conf
sed -i "s/\#   mail_location = maildir\:\~\/Maildir/mail_location = maildir\:\~\/Maildir/" /etc/dovecot/conf.d/10-mail.conf
sed -i "s/mail_location = mbox\:\~\/mail\:INBOX=\/var\/mail\/\%u/mail_location = mbox\:\~\/mail\:INBOX=\/var\/mail\/\%u/" /etc/dovecot/conf.d/10-mail.conf

systemctl restart postfix dovecot

sed -i "s/\$config\['default_host'\] = ''\;/\$config\['default_host'\] = '$namaDomain'\;/" /etc/roundcube/config.inc.php
sed -i "s/\$config\['smtp_server'\] = 'localhost'\;/\$config\['smtp_server'\] = '$namaDomain'\;/" /etc/roundcube/config.inc.php
sed -i "s/\$config\['smtp_port'\] = 587\;/\$config\['smtp_port'\] = 25\;/" /etc/roundcube/config.inc.php
sed -i "s/\$config\['smtp_user'\] = '\%u'\;/\$config\['smtp_user'\] = ''\;/" /etc/roundcube/config.inc.php
sed -i "s/\$config\['smtp_pass'\] = '\%p'\;/\$config\['smtp_pass'\] = ''\;/" /etc/roundcube/config.inc.php

echo -e "\nInstalasi & konfigurasi paket-paket mail server telah selesai!\n"

echo -e "======= STEP 5 - INSTALASI & KONFIGURASI CACTI ========\n"
echo "Sedang melakukan instalasi & konfigurasi cacti..."
apt-get install -qq -y cacti snmp snmpd rrdtool

chown -R www-data:www-data /usr/share/cacti
sed -i "s/agentaddress  127.0.0.1,\[\:\:1\]/agentaddress  udp\:"$ipDebian"\:161/" /etc/snmp/snmpd.conf

$rocommunity=$(cat /etc/snmp/snmpd.conf | grep "rocommunity public "$ipDebian"")
if [[ ! $rocommunity ]];
then
echo "rocommunity public "$ipDebian"" >> /etc/snmp/snmpd.conf
fi

systemctl restart snmpd

echo -e "\nInstalasi & konfigurasi paket-paket cacti telah selesai!\n"
