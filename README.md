#puppet-elasticsearch#

* Installs and runs elasticsearch as an upstart service

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

 Copyright (C) 2013 Jeff Vier <jeff@jeffvier.com> (Author)
 License: Apache 2.0
