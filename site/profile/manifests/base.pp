# This module is designed to provide an example to fulfill
# the PoC requirements of the client.
#
# Requirements:
# - puppetlabs/ntp
# - ghoneycutt/dnsclient
# - ghoneycutt/ssh
# - ghoneycutt/pam
# - kemra102/auditd
# - ppbrown/svcprop
# - saz/rsyslog
# - thias/postfix
#
class profile::base (
  $host_hash = hiera_hash(host_hash,''),
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

# This module handles NTP for Linux, Solaris 10 and Solaris 11
  include ntp

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
    # Need to find package for Solaris
  }
  elsif $::kernel == 'Linux' {
    package { 'sendmail':
      ensure => absent,
    }
    class { 'postfix::server':
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
    # fix
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
# hiera_hash:
#   - example1.host.com: 1.2.3.4
  unless $host_hash == '' {
    create_resources(host, $host_hash)
  }
}
