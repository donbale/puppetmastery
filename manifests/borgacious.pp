package { 'borgbackup':
    ensure => 'installed',
  }

file { '/etc/block-fuse':
  ensure => directory,
  recurse => true,
  mode   => '0755',
  source => '/etc/puppetlabs/code/environments/production/files/borgacious/block-fuse',
}

file { '/usr/local/bin/borgacious.sh':
  ensure => absent,
  mode   => '0755',
  source => '/etc/puppetlabs/code/environments/production/files/borgacious/borgacious.sh',
}

file { '/usr/local/bin/recoverone.sh':
  ensure => absent,
  mode   => '0755',
  source => '/etc/puppetlabs/code/environments/production/files/borgacious/recoverone.sh',
}

file { 'borgbackup':
    path    => "/etc/cron.d/borgbackup",
    ensure  => absent,
    owner   => "root",
    group   => "root",
    mode    => '0644',
    content => '* 22 * * * root /usr/local/bin/borgacious.sh >> /tmp/borgacious',
}
