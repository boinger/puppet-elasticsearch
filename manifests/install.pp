class elasticsearch::install(
  $aws_bucket, ## comment-out this parameter if you don't want to use S3 for the gateway
  $version           = "0.90.3",
  $install_root      = "/opt",
  $java_provider     = 'package',
  $java_package      = 'java-1.7.0-openjdk',
  $cloud_aws_plugin  = '1.14.0', ## https://github.com/elasticsearch/elasticsearch-cloud-aws
  $allow_restart     = false,
    ## service template options ##
  $gateway_type      = 's3',
  $replicas          = 1,
  $detail_status     = true,
  $run_as_user       = 'daemon',
  $ulimit_n          = 32768,
  $use_upstart       = true,
  $es_min_mem        = "2g",
  $es_max_mem        = "2g",
  $es_java_opts      = "",
  $index_buffer_size = "75%",
){

  $es_home          = "${install_root}/elasticsearch"

  if $java_provider == 'package' {
    if ! defined(Package[$java_package]) {
      package { "$java_package": }
    }
  }

  if $cloud_aws_plugin {
    exec {
      "install cloud-aws plugin":
        command => "/opt/elasticsearch/bin/plugin -install elasticsearch/elasticsearch-cloud-aws/${cloud_aws_plugin}",
        creates => "/opt/elasticsearch/plugins/cloud-aws/elasticsearch-cloud-aws-${cloud_aws_plugin}.jar",
        before  => Exec['restart elasticsearch'],
        require => [ File[$es_home], Exec['untar elasticsearch'], ];
    }
  }

  if $allow_restart {
    $restart_command = "stop elasticsearch; sleep 15; start elasticsearch"
  } else {
    $restart_command = 'true'
  }

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
      command     => $restart_command,
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
      require => File['elasticsearch servicewrapper conf'];

    'elasticsearch servicewrapper conf':
      path    => "${es_home}/bin/service/elasticsearch.conf",
      content => template('elasticsearch/elasticsearch-service.conf.erb'),
      require => Exec['install servicewrapper'];

    'elasticsearch.in.sh':
      path    => "${es_home}/bin/elasticsearch.in.sh",
      content => template('elasticsearch/elasticsearch.in.sh.erb'),
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
        Package['upstart'],
        Package[$java_package],
        File['elasticsearch servicewrapper file'],
      ];
  }

  #service{'elasticsearch':
    #ensure     => running,
    #enable     => true,
    #hasstatus  => true,
    #hasrestart => true,
    #require    => File['elasticsearch init script'];
  #}
}
