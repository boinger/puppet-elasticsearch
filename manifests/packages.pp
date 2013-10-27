class elasticsearch::packages inherits elasticsearch::params {

  if $java_package_name {
    $java_package = $java_package_name
  }

  if $java_provider == 'package' and ! defined(Package[$java_package]) {
    package { $java_package: }
  }

  if ! defined(Package[$git_package]) { package { $git_package: }}
  if ! defined(Package[$wget_package]) { package { $wget_package: }}
  if ! defined(Package[$upstart_package]) { package { $upstart_package: }}
}
