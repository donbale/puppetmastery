file { '/home/administrator/Linux_64':
  ensure => directory,
  mode   => '0755',
}

file { '/home/administrator/Linux_64/jre-11.0.1_linux-x64_bin.tar.gz':
  ensure => file,
  mode   => '0755',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/jre-11.0.1_linux-x64_bin.tar.gz',
}

file { '/home/administrator/Linux_64/pcns430.tar.gz':
  ensure => file,
  mode   => '0755',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/pcns430.tar.gz',
}

file { '/home/administrator/Linux_64/install.sh':
  ensure => file,
  mode   => '0755',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/install.sh',
}