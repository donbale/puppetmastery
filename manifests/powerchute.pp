exec { 'make_directory_powerchute':
  command => 'mkdir -p /home/administrator/Linux_64',
  path    => '/usr/local/bin/:/bin/',
}

file { '/home/administrator/Linux_64/jre-11.0.1_linux-x64_bin.tar.gz':
  ensure => file,
  mode   => '0777',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/jre-11.0.1_linux-x64_bin.tar.gz',
}

file { '/home/administrator/Linux_64/pcns430.tar.gz':
  ensure => file,
  mode   => '0777',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/pcns430.tar.gz',
}

file { '/home/administrator/Linux_64/install.sh':
  ensure => file,
  mode   => '0777',
  source => '/etc/puppetlabs/code/environments/production/files/powerchute/install.sh',
}

exec { 'setup_powerchute':
  require => File["/home/administrator/Linux_64/install.sh"],
  cwd	  => '/home/administrator/Linux_64',
  command => 'sudo /home/administrator/Linux_64/install.sh',
}