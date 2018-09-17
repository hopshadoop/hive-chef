include_recipe "java"

# Download Hive cleaner
package_url = "#{node['hive2']['hive_cleaner']['url']}"
base_package_filename = File.basename(package_url)
cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

remote_file cached_package_filename do
  source package_url
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "0644"
  action :create_if_missing
end

cleaner_downloaded = "#{node['hive2']['home']}/.cleaner_extracted_#{node['hive2']['hive_cleaner']['version']}"

bash 'extract-cleaner' do
        user "root"
        group node['hops']['group']
        code <<-EOH
                set -e
                tar zxf #{cached_package_filename} -C #{Chef::Config['file_cache_path']}
                mv #{Chef::Config['file_cache_path']}/hivecleaner-#{node['hive2']['hive_cleaner']['version']}/hive_cleaner #{node['hive2']['base_dir']}/bin/
                chown #{node['hops']['hdfs']['user']}:#{node['hops']['group']} #{node['hive2']['base_dir']}/bin/hive_cleaner
                touch #{cleaner_downloaded}
        EOH
     not_if { ::File.exists?( "#{cleaner_downloaded}" ) }
end

#Add the wiper
file "#{node['hive2']['base_dir']}/bin/wiper.sh" do
  action :delete
end

template "#{node['hive2']['base_dir']}/bin/wiper.sh" do
  source "wiper.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode 0755
end

ndb_mgmd_ip = private_recipe_ip("ndb", "mgmd")
template "#{node['hive2']['base_dir']}/bin/start-hivecleaner.sh" do
  source "start-hivecleaner.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  variables({
      :mgmd_endpoint => ndb_mgmd_ip
  })
  mode 0775
end

service_name="hivecleaner"
case node['platform_family']
when "rhel"
  systemd_script = "/usr/lib/systemd/system/#{service_name}.service"
else
  systemd_script = "/lib/systemd/system/#{service_name}.service"
end

service service_name do
  provider Chef::Provider::Service::Systemd
  supports :restart => true, :stop => true, :start => true, :status => true
  action :nothing
end

template systemd_script do
  source "#{service_name}.service.erb"
  owner "root"
  group "root"
  mode 0754
  if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => service_name)
  end
end

kagent_config service_name do
  action :systemd_reload
end

if node['kagent']['enabled'] == "true"
   kagent_config service_name do
     service "Hive"     
     log_file node['hive2']['logs_dir'] + "/hivecleaner.log"
   end
end

