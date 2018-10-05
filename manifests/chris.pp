include apt

node 'chris' {
	package { 'vim':
		ensure => 'present'
	}

	package { 'emacs':
		ensure => 'absent'
	}
}
	
