Summary: Daemon to push per-second iostat results to Zabbix
Name: zabbix-iostat
Version: 1.1
Release: 2%{?dist}
Source: zabbix-iostat-1.1.tar.gz
License: Apache v2
BuildRoot: /var/tmp/%{name}-buildroot 
Requires: perl-TimeDate

%description

%prep

%setup

%install
mkdir -p %{buildroot}/etc/cron.d/
mkdir -p %{buildroot}/usr/bin/
mkdir -p %{buildroot}/usr/share/doc/zabbix-iostat-%{version}/
mkdir -p %{buildroot}/usr/lib/systemd/system/
mkdir -p %{buildroot}/etc/zabbix/zabbix-agentd.d/

pwd
ls -la
cp iostat-collect.sh iostat-parse.sh zab-iostat-hires.pl %{buildroot}/usr/bin/
cp zabbix-iostat.service %{buildroot}/usr/lib/systemd/system/
cp zabbix-iostat.cron %{buildroot}/etc/cron.d
cp zabbix-iostat.spec iostat-disk-utilization-template.xml %{buildroot}/usr/share/doc/zabbix-iostat-%{version}/
cp iostat.conf %{buildroot}/etc/zabbix/zabbix-agentd.d/

%pre 

%post 

echo ""
echo "WARNING: zabbix_sender is required, but some Zabbix packagers put it in a separate zabbix-sender package"
echo ""
systemctl start zabbix-iostat.service
systemctl restart zabbix-agent.service

%files
/usr/bin/iostat-collect.sh
/usr/bin/iostat-parse.sh
/usr/bin/zab-iostat-hires.pl
/usr/lib/systemd/system/zabbix-iostat.service
/etc/cron.d/zabbix-iostat.cron
/etc/zabbix/zabbix-agentd.d/iostat.conf

%doc
/usr/share/doc/zabbix-iostat-%{version}/zabbix-iostat.spec
/usr/share/doc/zabbix-iostat-%{version}/iostat-disk-utilization-template.xml

%preun 
systemctl stop zabbix-iostat

%postun 
systemctl daemon-reload

