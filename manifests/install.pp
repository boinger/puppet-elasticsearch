class elasticsearch::install(
  $role                    = "combo",  ## or "master" or "data" or "client"
  $version                 = "0.90.10",
  $install_root            = "/opt",
  $java_provider           = 'package',
  $java_package            = 'jdk', ## Use Oracle JDK
  $cloud_aws_plugin        = '1.16.0', ## https://github.com/elasticsearch/elasticsearch-cloud-aws
  $allow_restart           = false,
    ## service template options ##
  $gateway_type            = 'local',
  $discovery_ec2_host_type = 'private_ip',
  $number_of_shards        = 5,
  $number_of_replicas      = 1,
  $cluster_name            = 'elasticsearch',
  $cluster_node_count      = 2,  # node count, if you are using normal "combined" nodes
  $cluster_data_node_count = 0,  # data node count, if you're splitting among data, master, and client.
  $detail_status           = true,
  $run_as_user             = 'daemon',
  $ulimit_n                = 32768,
  $use_upstart             = true,
  $es_min_mem              = "2g",
  $es_max_mem              = "2g",
  $es_java_opts            = "",
  $index_buffer_size       = "25%",
  $flush_threshold_ops     = 10000,
  $tcpcompress             = true,
  $mlockall                = true,
  $max_content_length      = '500mb',
  $config_template         = 'elasticsearch/elasticsearch.yml.erb',
){

  if $cluster_data_node_count > 0 {
    $half_cluster_data_node_count = inline_template("<%= (@cluster_data_node_count.to_f * 0.75).to_i %>")
  } else {
    $half_cluster_node_count = inline_template("<%= (@cluster_node_count.to_f * 0.75).to_i %>")
  }

  $es_home          = "${install_root}/elasticsearch"

  if $role == 'combo' {
    $nodemaster = 'true'
    $nodedata = 'true'
    $http_enabled = 'true'
  } elsif $role == 'master' {
    $nodemaster = 'true'
    $nodedata = 'false'
    $http_enabled = 'true'
  } elsif $role == 'data' {
    $nodemaster = 'false'
    $nodedata = 'true'
    $http_enabled = 'true'  ## needs to remain on if you're collecting stats!
  } elsif $role == 'client' {
    $nodemaster = 'false'
    $nodedata = 'false'
    $http_enabled = 'true'
  }

  if $java_provider == 'package' {
    if ! defined(Package[$java_package]) {
      package { "$java_package": }
    }
  }

  if $cloud_aws_plugin {
    exec {
      "install cloud-aws plugin":
        command => "/opt/elasticsearch/bin/plugin -remove elasticsearch/elasticsearch-cloud-aws/* ; /opt/elasticsearch/bin/plugin -install elasticsearch/elasticsearch-cloud-aws/${cloud_aws_plugin}",
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

    "${es_home}/bin/es_unassigned.rb":
      owner   => $run_as_user,
      mode    => 0755,
      source  => "puppet:///modules/${module_name}/es_unassigned.rb";

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
      content => template($config_template),
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
