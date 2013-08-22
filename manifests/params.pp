class elasticsearch::params(

  $version           = undef,
  $install_root      = undef,
  $java_provider     = undef,
  $java_package_name = undef,
  $cloud_aws_plugin  = undef,
  $detail_status     = undef,
  $run_as_user       = undef,
  $ulimit_n          = undef,
  $use_upstart       = undef,
  $es_min_mem        = undef,
  $es_max_mem        = undef,
  $index_buffer_size = undef,

) {

  $es_home = "${install_root}/elasticsearch"

  case $::osfamily {
    'RedHat': {
      case $::operatingsystem {
        'Scientific': {
          $java_package    = 'java-1.7.0-openjdk'
          $git_package     = 'git'
          $wget_package    = 'wget'
          $upstart_package = 'upstart'
        }
      }
    }
    'debian': {
      case $::operatingsystem {
        'Ubuntu': {
          $java_package    = 'openjdk-7-jdk'
          $git_package     = 'git-core'
          $wget_package    = 'wget'
          $upstart_package = 'upstart'
        }
        default: {
          $java_package    = 'java-1.7.0-openjdk'
          $git_package     = 'git'
          $wget_package    = 'wget'
          $upstart_package = 'upstart'
        }
      }
    }
  }
}
