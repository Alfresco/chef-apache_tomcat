# Copyright 2015 Drew A. Blessing
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

require 'poise'

module ApacheTomcat
  class Resource < Chef::Resource
    include Poise

    provides :apache_tomcat
    actions :install, :uninstall

    attribute :name, kind_of: String
    attribute :url,
              kind_of: String,
              default: 'http://archive.apache.org/dist/tomcat/tomcat-8/v8.0.24/bin/apache-tomcat-8.0.24.tar.gz'
    attribute :checksum,
              kind_of: String,
              default: '41980bdc3a0bb0abb820aa8ae269938946e219ae2d870f1615d5071564ccecee'
    attribute :version, kind_of: String, default: '8.0.24'
    attribute :prefix_root, kind_of: String, default: '/usr/share'
    attribute :user, kind_of: String, default: 'tomcat'
    attribute :group, kind_of: String, default: 'tomcat'
  end

  class Provider < Chef::Provider
    include Poise

    provides :apache_tomcat

    def action_install
      notifying_block do
        create_user
        install_archive
        preserve_bundle_wars
        remove_unnecessary_files
      end
    end

    def create_user
      Chef::Log.debug("Creating user #{new_resource.user} and group #{new_resource.group}")
      group new_resource.group

      user new_resource.user do
        gid new_resource.group
        comment 'Apache Tomcat'
        home new_resource.prefix_root
        shell '/sbin/nologin'
      end
    end

    def install_archive
      Chef::Log.debug("Installing #{new_resource.name} from archive")
      ark new_resource.name do
        url new_resource.url
        checksum new_resource.checksum
        version new_resource.version
        prefix_root new_resource.prefix_root
        prefix_home new_resource.prefix_root
        owner new_resource.user
        group new_resource.group
        append_env_path false
      end
    end

    def preserve_bundle_wars
      # Create bundle_wars directory in CATALINA_HOME
      Chef::Log.debug("Create directory for tomcat bundle wars in #{home_dir}")
      bundle_war_dir = "#{home_dir}/bundle_wars"
      directory bundle_war_dir do
        owner new_resource.user
        group new_resource.group
        mode '0755'
        recursive true
        action :create
      end
      # War up default webapps and send to bundle_wars directory in CATALINA_HOME
      Chef::Log.debug("Preserve default tomcat bundle wars in #{home_dir}/webapps")
      dirs = %w(ROOT docs examples host-manager manager)
      dirs.each do |webapp|
        Chef::Log.debug("Preserving #{webapp}.war to #{bundle_war_dir}")
        execute "Preserve #{webapp}.war" do
          command "/usr/bin/jar cfM #{bundle_war_dir}/#{webapp}.war -C #{home_dir}/webapps/#{webapp} ."
          only_if { ::Dir.exist?("#{home_dir}/webapps/#{webapp}") }
        end
      end
    end

    def remove_unnecessary_files
      Chef::Log.debug("Removing unecessary base directories from #{home_dir}")
      dirs = %w(temp webapps work logs)
      dirs.each do |dir|
        Chef::Log.debug("Ensure unnecessary directory #{dir} is removed")
        directory "#{home_dir}/#{dir}" do
          recursive true
          action :delete
        end
      end
    end

    def home_dir
      "#{new_resource.prefix_root}/tomcat"
    end
  end
end
