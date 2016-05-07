# This module is designed to provide an example to fulfill
# the PoC requirements of the client.
#
# Requirements:
# - puppetlabs/ntp
# - ghoneycutt/dnsclient
# - ghoneycutt/ssh - Version 3.31.0 due to a bug for Solaris introduced in 3.33.1
# - ghoneycutt/pam
# - kemra102/auditd
# - ppbrown/svcprop
# - saz/rsyslog
# - seteam/opencsw
# - thias/postfix
#
class profile::base (
  Hash $host_hash = hiera_hash(host_hash,{}),
) {

# Handle DNS
  if $::kernelrelease == '5.11' {
    svcprop { 'Search Domain':
      fmri     => 'network/dns/client',
      property => 'config/search',
      value    => 'i2cinc.com',
    }
    svcprop { 'Nameservers':
      fmri     => 'network/dns/client',
      property => 'config/nameserver',
      value    => '8.8.8.8 8.8.4.4 208.67.222.222 208.67.220.220',
    }
  }
  else {  #possibly restrict this to just Linux and Solaris 10 and fail otherwise?
# This module handles DNS for Linux and Solaris 10
    include dnsclient
  }

# This module handles NTP for Linux and Solaris 11.  It does not support Solaris 10
# however the ghoneycutt/ntp module does and should be a drop in replacement
  unless $::kernelrelease == '5.10' {
    include ntp
  }

# This module handles SSH hardening for Linux, Solaris 10 and Solaris 11
  include ssh

# Handle Password Policies
  if $::kernel == 'SunOS' {
    file { '/etc/default/passwd':
      ensure => file,
      source => 'puppet:///modules/profile/solarispasswd',
      mode   => '0644',
    }
    file { '/etc/default/login':
      ensure => file,
      source => 'puppet:///modules/profile/solarislogin',
      mode   => '0644'
    }
    file_line { 'TMOUT':
      ensure => present,
      path   => '/etc/profile',
      line   => 'TMOUT=900',
      match  => '^TMOUT',
    }
    file_line { 'UMASK':
      ensure => present,
      path   => '/etc/profile',
      line   => 'UMASK=022',
      match  => '^UMASK',
    }
    file_line { 'TCP_STRONG_ISS':
      ensure => present,
      path   => '/etc/default/inetinit',
      line   => 'TCP_STRONG_ISS=2',
      match  => '^TCP_STRONG_ISS',
    }
    file_line { 'ENABLE_NOBODY_KEYS':
      ensure => present,
      path   => '/etc/default/keyserv',
      line   => 'ENABLE_NOBODY_KEYS=NO',
      match  => '^ENABLE_NOBODY_KEYS',
    }
  }
# This module handles password policies for Linux
  elsif $::kernel == 'Linux' {
    include pam
    file { '/etc/login.defs':
      ensure => file,
      mode   => '0644',
      source => 'puppet:///modules/profile/login.defs'
    }
  }
  else {
    warning('This profile only supports password policies for Linux and Solaris')
  }
# Handle Syslog
  if $::kernel == 'SunOS' {
    file { '/etc/syslog':
      ensure => 'file',
      mode   => '0644',
      source => 'puppet:///modules/profile/solarissyslog',
      notify => Service['system-log'],
    }
    service { 'system-log':
      ensure => running,
      enable => true,
    }
  }
  elsif $::kernel == 'Linux' {
    include rsyslog # This appears to be broken for /etc/sysconfig/rsyslog
    file { '/etc/rsyslog.d/i2c.conf':
      ensure => file,
      mode   => '0644',
      source => 'puppet:///modules/profile/linuxrsyslog',
      notify => Service['rsyslog'],
    }
  }
  else {
    warning('This profile only supports syslog policies for Linux and Solaris')
  }

# Handle Postfix
  if $::kernel == 'SunOS' {
    package { ['sendmail','smtp-notify']:
      ensure => absent,
    }
# This sets up the opencsw postfix, which has packages in /etc/opt and /opt
# directories instead of the traditional locations.  May not be acceptable
# for this use case.  Additionally this method of configuring the settings
# is limited at best, and currently breaking on multiple matches.
    contain opencsw
    package {'postfix':
      ensure   => present,
      provider => 'pkgutil',
      require  => Class['opencsw'],
    }
    file_line { 'Postfix Domain':
      ensure => present,
      path   => '/etc/opt/csw/postfix/main.cf',
      line   => 'mydomain = i2cinc.com',
      match  => '^?mydomain ='
    }
    file_line { 'Postfix Hostname':
      ensure => present,
      path   => '/etc/opt/csw/postfix/main.cf',
      line   => "myhostname = $::hostname",
      match  => '^myhostname ='
    }
    file_line { 'Relay Host':
      ensure => present,
      path   => '/etc/opt/csw/postfix/main.cf',
      line   => 'relayhost = mail.i2cinc.com',
      match  => '^relayhost ='
    }
  }
  elsif $::kernel == 'Linux' {
    package { 'sendmail':
      ensure => absent,
    }
    class { 'postfix::server':
      inet_interfaces         => 'all',
      mydomain                => 'i2cinc.com',
      relayhost               => 'mail.i2cinc.com',
      smtp_sasl_auth          => true,
      smtp_sasl_password_maps => 'hash:/etc/postfix/relay_passwd',
    }
  }
  else {
    warning('This profile only supports postfix policies for Linux and Solaris')
  }

# Handle Auditing
  if $::kernel == 'SunOS' {
    if $::kernelrelease == '5.11' {
# This handles all the required pieces except the line "usermod -K audit_flags=pf:no jdoe"
      exec { '/usr/sbin/auditconfig -setnaflags lo':
        unless => '/usr/bin/test "`/usr/sbin/auditconfig -getnaflags | md5sum`" = "11303f9f6e5f946f4f077cae09a9a1a3  -"',
        notify => Service['auditd'],
      }
      exec { '/usr/sbin/auditconfig -setflags lo,ss':
        unless => '/usr/bin/test "`/usr/sbin/auditconfig -getflags | md5sum`" = "ba7b8ed30d6621afd2544f7d540d3daf  -"',
        notify => Service['auditd'],
      }
      exec { '/usr/sbin/auditconfig -setplugin audit_syslog active p_flags=lo,ex,-fr,fw,fm,+fc,+fd':
        unless => '/usr/bin/test "`/usr/sbin/auditconfig -getplugin audit_syslog | md5sum`" = "87439b2505340f4a02c3e45ec6ac476c  -"',
        notify => Service['auditd'],
      }
      file { '/var/adm/auditlog':
        ensure => file,
        mode   => '0644',
        notify => Service['auditd'],
      }
      service { 'auditd':
        ensure => running,
        enable => true,
      }
    }
    elsif $::kernelrelease == '5.10' {
      file { '/etc/security/audit_control':
        ensure => file,
        mode   => '0644',
        source => 'puppet:///modules/profile/solaris10_audit_control',
      }
# This is broken because bsmconv wants you to hit 'y'.  Will need to pull script
# modify it to not need input and drop it back in a temp location.
#      exec { '/usr/bin/bash /etc/security/bsmconv; /usr/bin/touch /tmp/bsmconvrun':
#        creates => '/tmp/bsmconvrun',
#        require => File['/etc/security/audit_control'],
#      }
    }
  }
  elsif $::kernel == 'Linux' {
    class { 'auditd':
      space_left_action => 'syslog',
      action_mail_acct  => 'itops.apm@i2cinc.com',
    }
  }
  else {
    warning('This profile only supports audit policies for Linux and Solaris')
  }

# Handle host files
# This creates host entries for hosts listed in hiera yaml files
# in the following format:
# ---
# host_hash:
#   example1.host.com:
#     ip: 1.2.3.4
#   example2.host.com:
#     ip:5.6.7.8
#     comment: foo
#
  unless $host_hash == undef {
    create_resources(host, $host_hash)
  }
}
