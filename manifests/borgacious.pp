file { '/etc/block-fuse':
  ensure => directory,
  mode   => '0755',
  source => '/etc/puppetlabs/code/environments/production/files/borgacious/block-fuse',
}

file { '/home/administrator/borgacious.sh':
  ensure => file,
  mode   => '0755',
  source => '/etc/puppetlabs/code/environments/production/files/borgacious/borgacious.sh',
}
