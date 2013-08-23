class elasticsearch (

  $version           = "0.20.6",
  $install_root      = "/opt",
  $java_provider     = 'package',
  $java_package_name = undef,
  $cloud_aws_plugin  = false,
  $detail_status     = true,
  $run_as_user       = 'daemon',
  $ulimit_n          = 32768,
  $use_upstart       = true,
  $es_min_mem        = "2g",
  $es_max_mem        = "2g",
  $index_buffer_size = "75%",

) {

  class {'elasticsearch::params':
    version           => $version,
    install_root      => $install_root,
    java_provider     => $java_provider,
    java_package_name => $java_package_name,
    cloud_aws_plugin  => $cloud_aws_plugin,
    detail_status     => $detail_status,
    run_as_user       => $run_as_user,
    ulimit_n          => $ulimit_n,
    use_upstart       => $use_upstart,
    es_min_mem        => $es_min_mem,
    es_max_mem        => $es_max_mem,
    index_buffer_size => $index_buffer_size,
  }

  class {'elasticsearch::install': }
  class {'elasticsearch::packages':
    before => Class['elasticsearch::install']
  }

}
