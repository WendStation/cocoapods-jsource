
require "cocoapods-core/lockfile"
require 'fileutils'

module Pod
  class Command
    class Jsource < Command
      class Add < Jsource
        self.summary = 'Add source debugging function'

        self.description = <<-DESC
          Prints the content of the podspec(s) whose name matches `QUERY` to standard output.
        DESC

        self.arguments = [
            CLAide::Argument.new('QUERY', false),
        ]

        def self.options
          [
              ['--names', 'component names to be added'],
              ['--gits', 'componengs git url to be added'],
          ].concat(super)
        end

        def initialize(argv)
          @names = argv.option('names').split(',')
          @gits = argv.option('gits').split(',')
          @source_dir = Dir.pwd
          super
        end

        def validate!
          super
          help! 'component name is required.' unless @names.length > 0
          help! 'component git url is required.' unless @gits.length > 0
          help! 'names number must be equal to gits number' unless @names.length == @gits.length
          help! 'podfile.lock file is required. you need pod install/update' unless File.exist? config.lockfile_path
        end

        def run
          # 获取当前目录
          index = 0
          for component_name in @names
            version = component_version component_name
            git = @gits[index]
            source_path = get_source_path_from_binary component_name
            create_working_directory source_path
            content = `git clone -b #{component_name}-#{version} --depth 1 #{git} #{source_path}`
            `open #{component_name}`
            index = index + 1
          end
          UI.puts "tian源码成功"
        end

        def component_version(component_name)
          return unless File.exist? config.lockfile_path
          version=""
          lockfile = Lockfile.from_file config.lockfile_path
          dependencies = lockfile.internal_data["DEPENDENCIES"]
          dependencies.each do |dependency|
            list = dependency.split(" (")
            name = list[0]
            next unless name == component_name
            version = list[-1].sub(")", "").sub("=", "").sub(" ", "")
          end
          version
        end

        def get_source_path_from_binary(component_name)
          source_path = ""
          component_pod_path = config.sandbox_root + component_name
          binary_path_list = `find #{component_pod_path} -name "#{component_name}" -type f`.strip.split("\n").sort
          if binary_path_list.length > 0
            binary_file = binary_path_list[0]
            source_path_list = `dwarfdump -arch x86_64 #{binary_file} | grep 'DW_AT_name.*#{component_name}'`.strip.split("\n").sort
            source_path_list.each do |tmp_source_path|
              if tmp_source_path.include?("Pods/#{component_name}")
                source_path = tmp_source_path.strip.split("(\"")[-1].split(component_name)[0]
                break
              end
            end
          else
            # 可能是.a
            binary_file_name = "lib#{component_name}.a"
            binary_path_list = `find #{component_pod_path} -name "#{binary_file_name}" -type f`.strip.split("\n").sort
            if binary_file_name.length > 0
              binary_file = binary_path_list[0]
              source_path_list = `dwarfdump -arch x86_64 #{binary_file} | grep 'AT_name.*#{component_name}'`.strip.split("\n").sort
              source_path_list.each do |tmp_source_path|
                if tmp_source_path.include?("Pods/#{component_name}")
                  source_path = tmp_source_path.strip.split("(\"")[-1].split("component_name")[0]
                  break
                end
              end
            end
          end
          source_path
        end




        def create_working_directory(source_path)
          parent = source_path.split("T")[0]
          return unless parent.length >0
          return if Dir.exist? parent
          parent = File.expand_path(parent)
          `sudo -S mkdir -p #{parent}`
          `sudo -S chmod 757 #{parent}`
        end
      end
    end
  end
end

