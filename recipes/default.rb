#
# Cookbook Name:: wordpress
# Recipe:: default
#
# Copyright 2009-2010, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#



node["sites"].each do |site|

  if site['config']['software'] == "wordpress"
    
    application_set = site['config']['set']
    webserver = site['config']['webserver']
    
    node["databases"].each do |db|
      if db['config']['set'] == application_set
        wpDb = db
      end
    end

    site_fqdn = site['server_name']
    site_dir = site['document_root']

    node.set_unless['wordpress']['db']['password'] = secure_password
    node.set_unless['wordpress']['keys']['auth'] = secure_password
    node.set_unless['wordpress']['keys']['secure_auth'] = secure_password
    node.set_unless['wordpress']['keys']['logged_in'] = secure_password
    node.set_unless['wordpress']['keys']['nonce'] = secure_password


    if node['wordpress']['version'] == 'latest'
      # WordPress.org does not provide a sha256 checksum, so we'll use the sha1 they do provide
      require 'digest/sha1'
      require 'open-uri'
      local_file = "#{Chef::Config[:file_cache_path]}/wordpress-latest.tar.gz"
      latest_sha1 = open('http://wordpress.org/latest.tar.gz.sha1') {|f| f.read }
      unless File.exists?(local_file) && ( Digest::SHA1.hexdigest(File.read(local_file)) == latest_sha1 )
        remote_file "#{Chef::Config[:file_cache_path]}/wordpress-latest.tar.gz" do
          source "http://wordpress.org/latest.tar.gz"
          mode "0644"
         # action :create_if_missing
        end
      end
    else
      remote_file "#{Chef::Config[:file_cache_path]}/wordpress-#{node['wordpress']['version']}.tar.gz" do
        source "http://wordpress.org/wordpress-#{node['wordpress']['version']}.tar.gz"
        mode "0644"
      end
    end

    directory "#{site_dir}" do
      owner "root"
      group "root"
      mode "0755"
      action :create
      recursive true
    end

    execute "untar-wordpress" do
      cwd site_dir
      command "tar --strip-components 1 -xzf #{Chef::Config[:file_cache_path]}/wordpress-#{node['wordpress']['version']}.tar.gz"
      creates "#{site_dir}/wp-settings.php"
    end


    log "Navigate to 'http://#{site_fqdn}/wp-admin/install.php' to complete wordpress installation" do
      action :nothing
    end

    template "#{site_dir}/wp-config.php" do
      source "wp-config.php.erb"
      owner "root"
      group "root"
      mode "0644"
      variables(
        :database        => wpDb['name'],
        :user            => wpDb['user'],
        :password        => wpDb['password'],
        :auth_key        => node['wordpress']['keys']['auth'],
        :secure_auth_key => node['wordpress']['keys']['secure_auth'],
        :logged_in_key   => node['wordpress']['keys']['logged_in'],
        :nonce_key       => node['wordpress']['keys']['nonce']
      )
      notifies :write, "log[Navigate to 'http://#{site_fqdn}/wp-admin/install.php' to complete wordpress installation]"
    end

    service webserver do
      action :restart
    end

  end

end



