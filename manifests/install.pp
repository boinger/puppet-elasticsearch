class elasticsearch::install(
  $version        = "0.20.6",
  $install_root   = "/opt",
  ## service template options
  $detail_status  = true,
  $run_as_user    = 'logstash',
  $ulimit_n       = 32000,
  $use_upstart    = true,
  $es_min_mem     = "256m",
  $es_max_mem     = "2g",
){

  $es_home       = "${install_root}/elasticsearch"

  exec{
    'download elasticsearch':
      cwd       => $install_root,
      user      => root,
      command   => "/usr/bin/wget http://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${version}.tar.gz",
      creates   => "${install_root}/elasticsearch-${version}.tar.gz",
      require   => Package['wget'];

    'untar elasticsearch':
      cwd       => $install_root,
      user      => root,
      command   => "/bin/tar xvfz elasticsearch-${version}.tar.gz",
      creates   => "${es_home}-${version}",
      require   => Exec['download elasticsearch'];

    'clone servicewrapper':
      path    => ['/usr/bin','/bin'],
      cwd     => $install_root,
      user    => root,
      command => "git clone git://github.com/elasticsearch/elasticsearch-servicewrapper.git",
      creates => "${install_root}/elasticsearch-servicewrapper",
      require => [
        Exec['untar elasticsearch'],
        Package['git']
        ];

    'install servicewrapper':
      path    => ['/usr/bin','/bin'],
      cwd     => "${install_root}/elasticsearch-servicewrapper",
      user    => root,
      command => "git pull && cp -R service ../elasticsearch/bin/",
      creates => "${es_home}/bin/service",
      require => [
        Exec['clone servicewrapper'],
        File["${es_home}"],
        Package['git']
        ];

    ## Defined this way instead of as a Service since Puppet thinks upstart is Ubuntu-only >:|
    "restart elasticsearch":
      command     => "stop elasticsearch; start elasticsearch",
      refreshonly => true,
      require     => File['/etc/init/elasticsearch.conf'],
      subscribe   => File['/etc/init/elasticsearch.conf'];

  }

  file{
    "${es_home}":
      ensure  => "${es_home}-${version}",
      require => Exec['untar elasticsearch'];

    "${es_home}/logs":
      owner   => $run_as_user,
      mode    => 0775,
      ensure  => directory;

    "${es_home}/data":
      owner   => $run_as_user,
      mode    => 0775,
      ensure  => directory,
      require => File["${es_home"];

    'elasticsearch servicewrapper file':
      path    => "${es_home}/bin/service/elasticsearch",
      content => template('elasticsearch/elasticsearch-service.erb'),
      require => Exec['install servicewrapper'];

    'elasticsearch.yml':
      path    => "${es_home}/config/elasticsearch.yml",
      content => template('elasticsearch/elasticsearch.yml.erb'),
      require => Exec['install servicewrapper'];

    'elasticsearch upstart script':
      path    => '/etc/init/elasticsearch.conf',
      content => template('elasticsearch/elasticsearch.conf.erb'),
      require => [Package['upstart'], File['elasticsearch servicewrapper file'] ,];
  }

  #service{'elasticsearch':
    #ensure     => running,
    #enable     => true,
    #hasstatus  => true,
    #hasrestart => true,
    #require    => File['elasticsearch init script'];
  #}
}
