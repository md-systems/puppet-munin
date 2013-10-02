# Class munin::node
#
# Usage:
#
#  class { 'munin::node':
#    eipaddress     => '192.168.0.1', # explicit IP address
#    allowed_ips    => [ '192.168.1.10', '192.168.1.20', ],
#    listen_port    => '4949',
#    listen_address => '*',
#    ensure_service => running,
#    enable_service => true,
#
#  }

class munin::node (
    $ensure          = installed,
    $eipaddress      = undef,
    $listen_address  = '*',
    $listen_port     = '4949',
    $ignore_files    = [],
    $allowed_ips     = [],
    $ensure_service  = running,
    $enable_service  = true,
    $minimal_plugins = false,
) {

  case $::operatingsystem {
    centos, redhat, amazon: {
      $log_dir      = '/var/log/munin-node'
      $cidr_package = 'perl-Net-CIDR'
    }
    debian, ubuntu: {
      $log_dir      = '/var/log/munin'
      $cidr_package = 'libnet-cidr-perl'
    }
    default: { fail ("Error: Unrecognized operating system = ${::operatingsystem}") }
  }

  package { $cidr_package:
    ensure => installed,
  }

  package { 'munin-node':
    ensure  => $ensure,
    require => Package[$cidr_package],
  }

  service { 'munin-node':
    ensure     => $ensure_service,
    enable     => $enable_service,
    hasrestart => true,
    hasstatus  => true,
    require    => Package['munin-node'],
  }

  file { 'munin-node.conf':
    ensure    => file,
    owner     => root,
    group     => root,
    mode      => '0644',
    path      => '/etc/munin/munin-node.conf',
    content   => template('munin/munin-node.conf.erb'),
    require   => Package['munin-node'],
    notify    => Service['munin-node'],
  }

  # NOTE: minimize enabled plugins to decrease graphs
  if $minimal_plugins {
    Exec {
      path      => [ '/bin/', '/usr/bin ', '/sbin', ],
      logoutput => on_failure,
    }

    # put the script to /tmp/ & then run it via exec
    file { 'plugins-minimal.sh':
      path   => '/etc/munin/plugins-minimal.sh',
      owner  => 'root',
      group  => 'root',
      mode   => '600',
      source => 'puppet:///modules/munin/plugins-minimal.sh',
      require   => Package['munin-node'],
    }

    exec { 'plugins-minimal':
      command     => 'bash /etc/munin/plugins-minimal.sh',
      user        => 'root',
      group       => 'root',
      refreshonly => true,
      subscribe   => File['plugins-minimal.sh'],
      notify      => Service['munin-node'],
    }

  }

  # NOTE: export munin-node info
  # this automatically adds the node to munin server 
  #   for monitoring once realized
  @@file { "/etc/munin/munin-conf.d/${::fqdn}.conf":
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    tag     => ['munin-node', "munin-node-${::location}", "munin-node-${::company}", "munin-node-${::company}-${::location}"],
    content => template('munin/munin-conf-node-info.erb'),
  }

}
