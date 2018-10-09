node 'themachine' {
	package { 'vim':
		ensure => 'present'
	}

	package { 'emacs':
		ensure => 'absent'
	}
}
	
