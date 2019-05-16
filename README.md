# PuppetMastery

One Repo To Control Them All

## Getting Started

Puppet is a configuration management tool which allows us to have continuity on our linux based infrastructure.

To centralise matters I have adopted a masterless Puppet setup which requires a copy of all Puppet modules to be copied to each node via Git and then Puppet will apply the appropriate changes locally.

 
### Prerequisites

You need Puppet and Git installed on your system, I'm going to go ahead and presume you either have git or know how to *git* it.

Here's how to install Puppet:

Ubuntu: 

```
wget https://apt.puppetlabs.com/puppet5-release-xenial.deb
sudo dpkg -i puppet5-release-xenial.deb
sudo apt update
sudo apt install puppet-agent
```

Centos7:

```
sudo rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
sudo yum install puppet
```

```
sudo rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm
sudo yum install puppet
```

### Installing

Once you have installed the necessaries the next step is to install this repo into your puppet production environment by following these steps...

```
cd /etc/puppetlabs/code/environments
sudo mv production production.sample
sudo git clone git clone https://{YOUR_USER_ID}@bitbucket.org/arianetworks/puppetmastery.git production
```

Once complete just run this command:

```
puppet apply manifest
```

## Current Puppet Tasks

* Running Puppet Every Hour

* Backing up LVM based KVMs


## Authors

* **Chris Bale** - *Initial work* - [DonBale](https://github.com/donbale)

