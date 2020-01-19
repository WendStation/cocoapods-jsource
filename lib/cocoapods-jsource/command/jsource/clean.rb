require "cocoapods-core/lockfile"
require 'fileutils'

module Pod
  class Command
    class Jsource < Command
      class Clean < Jsource
        self.summary = 'Clean source debugging function'

        self.description = <<-DESC
          Remove the cache for a given pod, or clear the cache completely.

          If you want to clean Debug_xcodeproj, please add "NAME",
          if you want to clean all, please add "—all"

          If you want to clear the cache, add "--cache":

              If there is multiple cache for various versions of the requested pod, you
              will be asked which one to clean. Use `--all` to clean them all.

              If you do not give a pod `NAME`, you need to specify the `--all` flag
              (this is to avoid cleaning all the cache by mistake).

        DESC

        self.arguments = [
            CLAide::Argument.new('NAME', false),
        ]

        def self.options
          [
              ['--all', 'Remove all the project debug pods without asking'],
              ['--cache', 'Remove all the cached pods without asking']
          ].concat(super)
        end

        def initialize(argv)
          @pod_name = argv.shift_argument
          @wipe_all = argv.flag?('all')
          @wipe_cache = argv.flag?('cache')
          @cache_dict = cache_object
          @manager = XcodeManager.new(argv)
          super
        end

        def validate!
          super
          if @pod_name.nil?
            help! 'You should use the --all flag' if @wipe_all.nil?
          end
        end

        def run
          if @pod_name.nil?
            # Note: at that point, @wipe_all is always true (thanks to `validate!`)
            if @wipe_all
              if @wipe_cache
                clear_cache
              else
                @manager.clean_debug
              end
            end
          else
            # Remove only cache for this pod
            if @wipe_cache
              cache_descriptors = @cache_dict[@pod_name].values
              if cache_descriptors.nil?
                UI.notice("No cache for pod named #{@pod_name} found")
              elsif cache_descriptors.count > 1 && !@wipe_all
                # Ask which to remove
                choices = cache_descriptors.map { |c| "#{@pod_name} v#{c[:version]}" }
                index = UI.choose_from_array(choices, 'Which pod cache do you want to remove?')
                # 删除debug
                remove_caches([cache_descriptors[index]])
              else
                # Remove all found cache of this pod
                remove_caches(cache_descriptors)
              end
            else
              @manager.remove_component_from_debug(@pod_name)
            end
          end
        end

        private

        # Removes the specified cache
        #
        # @param [Array<Hash>] cache_descriptors
        #        An array of caches to remove, each specified with the same
        #        hash as cache_descriptors_per_pod especially :source and :version
        #
        def remove_caches(cache_descriptors)
          cache_descriptors.each do |desc|
            source_paths = desc[:source_paths]
            next if source_paths.length == 0
            source_paths.each do |binary_name, source_path|
              UI.puts "Removing cache #{source_path} (#{desc[:version]})"
              parent = source_path.split("Pods")[0]
              FileUtils.rm_rf(parent) if File.exist? parent
            end
            if @cache_dict[@pod_name].has_key? desc[:version]
              if @cache_dict[@pod_name].length == 1
                @cache_dict.delete @pod_name
              else
                @cache_dict[@pod_name].delete (desc[:version]) if @cache_dict[@pod_name].has_key? desc[:version]
              end
            end
          end
          dump_to_yaml @cache_dict
        end

        def clear_cache
          @cache_dict.each do |pod_name, version_dict|
            version_dict.each do |version, pod_dict|
              source_paths=pod_dict[:source_paths] if pod_dict.has_key? :source_paths
              source_paths.each do |binary_name, source_path|
                UI.message("Removing the #{binary_name} jsource cache dir #{source_path}") do
                  parent = source_path.split("Pods")[0]
                  FileUtils.rm_rf(parent) if File.exist? parent
                end
              end
            end
          end
          UI.message("Removing the jsource configuration dir #{cache_file}") do
            FileUtils.rm_rf(cache_file)
            @cache_dict = {}
          end
          dump_to_yaml @cache_dict
        end
      end
    end
  end
end

