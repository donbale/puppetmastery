file { '/tmp/jre-11.0.1_linux-x64_bin.tar.gz':
  ensure => file,
  owner  => 'administrator',
  group  => 'administrator',
  mode   => '0700',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/jre-11.0.1_linux-x64_bin.tar.gz',
}

file { '/tmp/pcns430.tar.gz':
  ensure => file,
  owner  => 'administrator',
  group  => 'administrator',
  mode   => '0700',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/pcns430.tar.gz',
}

file { '/tmp/install.sh':
  ensure => file,
  owner  => 'administrator',
  group  => 'administrator',
  mode   => '0700',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/install.sh',
}

exec { 'setup_powerchute':
  require => File["/tmp/install.sh"],
  refreshonly => true,
  command => '/tmp/install.sh',
  user    => 'administrator',
  group   => 'administrator',
}