
require 'cocoapods-jsource/command/jsource/add'
require 'cocoapods-jsource/command/jsource/clean'
require 'cocoapods-jsource/command/jsource/list'

module Pod
  class Command
    # This is an example of a cocoapods plugin adding a top-level subcommand
    # to the 'pod' command.
    #
    # You can also create subcommands of existing or new commands. Say you
    # wanted to add a subcommand to `list` to show newly deprecated pods,
    # (e.g. `pod list deprecated`), there are a few things that would need
    # to change.
    #
    # - move this file to `lib/pod/command/list/deprecated.rb` and update
    #   the class to exist in the the Pod::Command::List namespace
    # - change this class to extend from `List` instead of `Command`. This
    #   tells the plugin system that it is a subcommand of `list`.
    # - edit `lib/cocoapods_plugins.rb` to require this file
    #
    # @todo Create a PR to add your plugin to CocoaPods/cocoapods.org
    #       in the `plugins.json` file, once your plugin is released.
    #
    class Jsource < Command
      self.abstract_command = true
      self.summary = 'Manage source debugging'

      # self.description = <<-DESC
      #   Longer description of cocoapods-jsource.
      # DESC
      private

      def cache_dir
        path = "/Users/#{`whoami`.strip}/Library/Caches/CocoaPods/jsource/"
        if not Dir.exist? path
          `mkdir -p #{path}`
        end
        path
      end

      def cache_file
        cache_path = cache_dir
        return cache_path + "jsource.yaml"
      end

      def cache_object
        require 'yaml'
        cache_file_path = cache_file
        cache_dict = {}
        if File.exist? cache_file_path
          cache_dict = YAML.load(File.open(cache_file_path))
        end
        cache_dict
      end

      def version_from_path(component_name, path)
        cache_dict = cache_object
        version = nil
        cache_dict.each do |name, verision_hash|
          verision_hash.each do |version_string, detail_hash|
            return version unless detail_hash.include? :source_paths
            detail_hash[:source_paths].each do |binary_name, source_path|
              return version_string if source_path == path and binary_name == component_name
            end
          end
        end
        return version
      end


      def dump_to_yaml(hash)
        File.open(cache_file, "wb+") {|f| YAML.dump(hash, f) }
      end

      def output_pipe
        STDOUT
      end

      # def initialize(argv)
      #   @name = argv.shift_argument
      #   super
      # end

      # def validate!
      #   super
      #   help! 'A Pod name is required.' unless @name
      # end

      # def run
      #   UI.puts "Add your implementation for the cocoapods-jsource plugin in #{__FILE__}"
      # end
    end
  end
end
