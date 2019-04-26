file { '/root/powerchute/jre-11.0.1_linux-x64_bin.tar.gz':
  ensure => file,
  owner  => 'root',
  group  => 'root',
  mode   => '0700',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/jre-11.0.1_linux-x64_bin.tar.gz',
}

file { '/root/powerchute/pcns430.tar.gz':
  ensure => file,
  owner  => 'root',
  group  => 'root',
  mode   => '0700',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/pcns430.tar.gz',
}

file { '/root/powerchute':
  ensure => file,
  owner  => 'root',
  group  => 'root',
  mode   => '0700',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/install.sh',
}

exec { 'setup_powerchute':
  require => File["/root/powerchute/install.sh"],
  refreshonly => true,
  command => '/root/powerchute/install.sh',
  user    => 'root',
  group   => 'root',
}