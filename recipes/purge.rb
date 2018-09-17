bash 'kill_running_interpreters' do
    user "root"
    ignore_failure true
    code <<-EOF
      service hive stop
    EOF
end


directory node['hive']['home'] do
  recursive true
  action :delete
  ignore_failure true
end

link node['hive']['base_dir'] do
  action :delete
  ignore_failure true
end


package_url = "#{node['hive']['url']}"
base_package_filename = File.basename(package_url)
cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

file cached_package_filename do
  action :delete
  ignore_failure true
end

package_url = "#{node['tez']['url']}"
base_package_filename = File.basename(package_url)
cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

file cached_package_filename do
  action :delete
  ignore_failure true
end

