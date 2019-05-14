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
  ensure => file,
  mode   => '0755',
  source => '/etc/puppetlabs/code/environments/production/files/borgacious/borgacious.sh',
}

file { '/usr/local/bin/recoverone.sh':
  ensure => file,
  mode   => '0755',
  source => '/etc/puppetlabs/code/environments/production/files/borgacious/recoverone.sh',
}

cron { 'run-borgbackup':
  ensure => 'present',
  command => '/usr/local/bin/borgacious.sh >> /tmp/borgcron 2>&1',
  user  => root,
  hour    => '22',
  minute  => '0',
}