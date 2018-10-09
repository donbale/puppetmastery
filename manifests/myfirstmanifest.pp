file { '/tmp/hudson.txt':
	ensure => file,
	content => "NAME=Hudson_Bale_Burgos, DOB=(11.12.12), CHARS=[Highly Intelligent, Caring, Handsome, Strong]"
}
