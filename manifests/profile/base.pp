# This module is designed to provide an example to fulfill
# the PoC requirements of the client.
#
# Requirements:
# - ghoneycutt/dnsclient
# - puppetlabs/ntp
# - ghoneycutt/ssh
# - ghoneycutt/pam
#
class profile::base (
) {

# Handle DNS
  if $::kernelrelease == '5.11' {
    #handle dns on solaris 11
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

# This module handles password policies for Linux, Solaris 10 and Solaris 11
  if kernel == 'SunOS' {

  }

  elsif kernel == 'Linux' {
    include pam
  }
