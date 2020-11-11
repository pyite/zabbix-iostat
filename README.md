
zabbix-iostat - scripts to push per-second iostat data into Zabbix

Originally based on the Github project lesovsky / zabbix-extensions / files / iostat/

The main goal is to be able to look at real-time per-second iostat data in Grafana using this plugin
available from Github:  alexanderzobnin / grafana-zabbix 



There are two main components to this project:

1) A "low resolution" script to call via zabbix-agent.  By default this lets Zabbix grab data every minute

2) A "high resolution" script which pushes data via zabbix-sender every second



INSTALL

1) Set up zabbix-agent and zabbix-sender
2) Install systat (for iostat)
3) Install the zabbix-iostat package
4) Load the XML template into Zabbix (packaged in /usr/share/doc/zabbix-iostat)
5) Add the iostat template to your Zabbix host
6) ?
7) Profit!




TODO

 - Handle different iostat versions on different distros better
 - Add entries for read/write average request size (newer iostat versions split this out)
 - Try making a Prometheus version to speed up larger query sets


CONTACT

https://github.com/pyite/zabbix-iostat
mark@tpsit.com
lehrer@gmail.com
mark.lehrer@wdc.com
mlehrer@fusionio.com


