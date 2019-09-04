
require "cocoapods-core/lockfile"
require 'fileutils'

module Pod
  class Command
    class Jsource < Command
      class Clean < Jsource
        self.summary = 'Add source debugging function'

        self.description = <<-DESC
          Clean the cache of the jsource(s) whose name matches `NAME`.
        DESC

        self.arguments = [
            CLAide::Argument.new('NAME', false),
        ]

        def self.options
          [
              ['--all', 'Remove all the cached pods without asking'],
          ].concat(super)
        end

        def initialize(argv)
          @pod_name = argv.shift_argument
          @wipe_all = argv.flag?('all')
          @cache_dict = cache_object
          super
        end

        def validate!
          super
          if @pod_name.nil? && !@wipe_all
            # Security measure, to avoid removing the pod cache too agressively by mistake
            help! 'You should either specify a pod name or use the --all flag'
          end
        end

        def run
          if @pod_name.nil?
            # Note: at that point, @wipe_all is always true (thanks to `validate!`)
            # Remove all
            clear_cache
          else
            # Remove only cache for this pod
            cache_descriptors = @cache_dict[@pod_name].values
            if cache_descriptors.nil?
              UI.notice("No cache for pod named #{@pod_name} found")
            elsif cache_descriptors.count > 1 && !@wipe_all
              # Ask which to remove
              choices = cache_descriptors.map { |c| "#{@pod_name} v#{c[:version]}" }
              index = UI.choose_from_array(choices, 'Which pod cache do you want to remove?')
              remove_caches([cache_descriptors[index]])
            else
              # Remove all found cache of this pod
              remove_caches(cache_descriptors)
            end
          end
          dump_to_yaml @cache_dict
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
            sourcelist = desc[:sourcelist]
            next if sourcelist.length == 0
            sourcelist.each do |source|
              UI.puts "Removing cache #{source} (#{desc[:version]})"
              parent = source.split("Pods")[0]
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
        end

        def clear_cache
          @cache_dict.each do |pod_name, version_dict|
            version_dict.each do |version, pod_dict|
              git=""
              source=""
              git=pod_dict[:git] if pod_dict.has_key? :git
              sourcelist=pod_dict[:sourcelist] if pod_dict.has_key? :sourcelist
              sourcelist.each do |source|
                UI.message("Removing the #{pod_name} jsource cache dir #{cache_dir}") do
                  parent = source.split("Pods")[0]
                  FileUtils.rm_rf(parent) if File.exist? parent
                end
              end

            end
          end
          UI.message("Removing the jsource configuration dir #{cache_file}") do
            FileUtils.rm_rf(cache_file)
            @cache_dict = {}
          end
        end

      end
    end
  end
end

