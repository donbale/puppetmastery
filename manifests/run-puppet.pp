# Set up regular Puppet runs
file { '/usr/local/bin/run-puppet':
  source => '/etc/puppetlabs/code/environments/production/files/run-puppet.sh',
  mode   => '0755',
}

# cron { 'run-puppet':
#  command => '/usr/local/bin/run-puppet >> /tmp/puppetcron 2>&1',
#  user  => root,
#  hour    => '*',
#  minute  => '*/59',
#}

file { "puppet.cron":
    path    => "/etc/cron.d/puppet.cron",
    ensure  => present,
    owner   => "root",
    group   => "root",
    mode    => 0644,
    content => "*/59 * * * * root /usr/local/bin/run-puppet";
}
