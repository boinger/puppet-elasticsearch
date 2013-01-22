#puppet-elasticsearch#

* Installs and runs elasticsearch as an upstart service

* Pulls a specific version directly from github.  This isn't particularly ideal/best practice.  You should fork this and make it install a package from your locally hosted binary repo.

##Requirements##
* git
* upstart (though, this is easy to hack around if you prefer init.d)
* wget

##Usage##

###Basic:
```puppet
class { 'elasticsearch::install': }
```

###Override some stuff:
```puppet
class { 'elasticsearch::install':
  install_root => '/usr/local',
  run_as_user  => 'es-system',
}
```

##License##

 Copyright (C) 2013 Jeff Vier <jeff@jeffvier.com> (Author)<br />
 License: Apache 2.0
