class elasticsearch::install inherits elasticsearch::params {

  Exec {
    path => [
      '/bin',
      '/sbin',
      '/usr/bin',
      '/usr/sbin',
      '/usr/local/bin',
      '/usr/local/sbin',
      '/opt/bin',
      '/opt/sbin',
    ]
  }

  if $cloud_aws_plugin {
    exec {
      "install cloud-aws plugin":
        command => "/opt/elasticsearch/bin/plugin -install elasticsearch/elasticsearch-cloud-aws/${cloud_aws_plugin}",
        creates => "/opt/elasticsearch/plugins/cloud-aws",
        before  => Exec['restart elasticsearch'],
        require => [
          File[$es_home],
          Exec['untar elasticsearch'],
        ];
    }
  }

  exec{
    'download elasticsearch':
      command   => "wget http://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${version}.tar.gz",
      cwd       => $install_root,
      user      => root,
      creates   => "${install_root}/elasticsearch-${version}.tar.gz",
      require   => [
        Package[$wget_package],
      ];

    'untar elasticsearch':
      command   => "tar xvfz elasticsearch-${version}.tar.gz",
      cwd       => $install_root,
      user      => root,
      creates   => "${es_home}-${version}",
      require   => Exec['download elasticsearch'];

    'clone servicewrapper':
      command => "git clone git://github.com/elasticsearch/elasticsearch-servicewrapper.git",
      cwd     => $install_root,
      user    => root,
      creates => "${install_root}/elasticsearch-servicewrapper",
      require => [
        Package[$git_package],
        Exec['untar elasticsearch'],
      ];

    'install servicewrapper':
      command => "git pull && cp -R service ../elasticsearch/bin/",
      cwd     => "${install_root}/elasticsearch-servicewrapper",
      user    => root,
      creates => "${es_home}/bin/service",
      require => [
        Package[$git_package],
        Exec['clone servicewrapper'],
        File["${es_home}"],
      ];

    ## Defined this way instead of as a Service since Puppet thinks upstart is Ubuntu-only >:|
    "restart elasticsearch":
      command     => "stop elasticsearch; sleep 15; start elasticsearch",
      refreshonly => true,
      require     => File['/etc/init/elasticsearch.conf'],
      subscribe   => File['/etc/init/elasticsearch.conf'];
  }

  #service{'elasticsearch':
    #ensure     => running,
    #enable     => true,
    #hasstatus  => true,
    #hasrestart => true,
    #require    => File['elasticsearch init script'];
  #}

  file {
    "${es_home}":
      ensure  => "${es_home}-${version}",
      require => Exec['untar elasticsearch'];

    "${es_home}/logs":
      owner   => $run_as_user,
      mode    => 0775,
      ensure  => directory,
      require => File["${es_home}"];

    "${es_home}/data":
      owner   => $run_as_user,
      mode    => 0775,
      ensure  => directory,
      require => File["${es_home}"];

    'elasticsearch servicewrapper file':
      path    => "${es_home}/bin/service/elasticsearch",
      content => template('elasticsearch/elasticsearch-service.erb'),
      require => Exec['install servicewrapper'];

    'elasticsearch.yml':
      path    => "${es_home}/config/elasticsearch.yml",
      content => template('elasticsearch/elasticsearch.yml.erb'),
      mode    => 0644,
      notify  => Exec['restart elasticsearch'],
      require => Exec['install servicewrapper'];

    'logging.yml':
      path    => "${es_home}/config/logging.yml",
      content => template('elasticsearch/logging.yml.erb'),
      mode    => 0644,
      notify  => Exec['restart elasticsearch'],
      require => Exec['install servicewrapper'];

    'elasticsearch upstart script':
      path    => '/etc/init/elasticsearch.conf',
      content => template('elasticsearch/elasticsearch.conf.erb'),
      require => [
        Package[$upstart_package],
        Package[$java_package],
        File['elasticsearch servicewrapper file'],
      ];
  }
}
