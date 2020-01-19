require 'xcodeproj'
require 'cocoapods'
require 'cocoapods-jsource/command/xcodeproj_extern'

module Pod
  class Command
    class Jsource < Command
      class XcodeManager < Jsource

        def initialize(argv)
          @debug_path = 'Pods/Debug.xcodeproj'
          @workspace_name = `ls | grep .xcworkspace`.strip
          @cache_dict = cache_object
          super
        end

        def validate!
          super
          help! '请先pod install/update 之后,在运行这个命令' if !File.exist? @workspace_name or !File.exist? "Pods"
        end

        def generate_debug_xcodeproj()
          debug_xcodeproj = get_debug_xcodeproj
          if debug_xcodeproj.nil?
            debug_xcodeproj = Xcodeproj::Project.new(@debug_path)
            # 去掉Frameworks和Products
            #debug_xcodeproj.groups.each do |component_group|
            #  component_group.clear
            #  component_group.remove_from_project
            #end
          end
          debug_xcodeproj
        end

        def get_debug_xcodeproj()
          debug_xcodeproj = nil
          if File.exist? @debug_path
            debug_xcodeproj = Xcodeproj::Project.open(@debug_path)
          end
          debug_xcodeproj
        end

        def add_files_to_group(debug_xcodeproj, group, files=[])
          Dir.foreach(group.real_path).sort_by { |object| object.to_s }.each do |entry|
            filePath = File.join(group.real_path, entry)
            next unless files.length == 0 or files.include? filePath
            ext_name = File.extname(entry)
            # 过滤目录和.DS_Store文件
            if !File.directory?(filePath) && entry != ".DS_Store" then
              # 向group中增加文件引用
              group.new_reference(filePath)
              # 目录情况下, 递归添加
            elsif File.directory?(filePath) && entry != '.' && entry != '..' then
              hierarchy_path = group.hierarchy_path[1, group.hierarchy_path.length]
              subGroup = debug_xcodeproj.main_group.find_subpath(hierarchy_path + '/' + entry, true)
              subGroup.set_source_tree('<group>')
              subGroup.set_path(group.real_path + entry)
              add_files_to_group(debug_xcodeproj, subGroup, files)
            end
          end
        end

        # 感觉没啥必要
        def include_component(component_name, source_path, debug_xcodeproj)
          debug_xcodeproj.groups.each do |group|
            return true if group.name == component_name and File.exist? group.path
          end
          return false
        end


        def all_components_in_debug()
          component_info = {}
          debug_xcodeproj = get_debug_xcodeproj
          if debug_xcodeproj.nil?
            return component_info
          end
          debug_xcodeproj.groups.each do |component_group|
            detail_hash = {}
            source_path_hash = {}
            source_path_hash[component_group.display_name] = component_group.real_path.to_s
            detail_hash[:source_paths] = source_path_hash
            version = version_from_path component_group.display_name, component_group.real_path.to_s
            detail_hash[:version] = version if version
            component_info[component_group.display_name] = detail_hash if detail_hash.length > 0
          end
          component_info
        end

        def component_in_debug(component_name)
          all_component_hash = all_components_in_debug
          component_hash = {}
          all_component_hash.each do |binary_name, detail_hash|
            if binary_name.start_with? component_name
              component_hash[binary_name] = detail_hash
            end
          end
          component_hash
        end

        def avaliable_dirs(file_path, dest_file_path)
          dir_list = []
          if file_path.to_s == dest_file_path.to_s
            return dir_list
          else
            parent_dir = File.dirname file_path
            dir_list << parent_dir
            dir_list = dir_list | avaliable_dirs(parent_dir, dest_file_path)
          end
          dir_list
        end

        def avaliable_file(group, spec)
          component_name = spec.name
          subspec = group.name.gsub(/#{component_name}/, "")
          files = []
          if subspec
            spec.subspecs.each do |subspec_spec|
              next unless subspec_spec.name == "#{component_name}/#{subspec}"
              source_files = "#{group.real_path}/#{subspec_spec.attributes_hash["source_files"]}"
              tmp_files = Dir.glob (source_files)
              # 找到所有的文件夹
              tmp_files.each do |file_path|
                files << file_path
                parent_path = File.dirname file_path
                if !files.include? parent_path
                  files = files | avaliable_dirs(file_path, group.real_path)
                end
              end
              break
            end
          end
          files
        end

        def add_component_to_debug(component_name, source_path_hash, debug_xcodeproj, spec)
          source_path_hash.each do |binary_name, source_path|
            # 将源码添加到Debug.xcodeproj 里。
            UI.puts "add #{binary_name} to Debug.xcodeproj"
            component_group = debug_xcodeproj.main_group.find_subpath(binary_name, true)
            component_group.set_source_tree('<absolute>')
            component_group.set_path(source_path)
            component_group.clear
            files = avaliable_file component_group, spec
            add_files_to_group(debug_xcodeproj, component_group, files)
          end
          debug_xcodeproj.save
        end

        def remove_component_from_debug(component_name)
          debug_xcodeproj = get_debug_xcodeproj
          if debug_xcodeproj.nil?
            return
          end
          debug_xcodeproj.groups.each do |component_group|
            if component_group.display_name.start_with? component_name
              UI.puts "removing #{component_group.display_name} from Debug.xcodeproj"
              if !component_group.empty?
                component_group.clear
                component_group.remove_from_project
              end
            end
          end
          debug_xcodeproj.save
        end

        def clean_debug()
          debug_xcodeproj = get_debug_xcodeproj
          remove_debug_from_workspace
          if debug_xcodeproj
            FileUtils.rm_rf [@debug_path]
          end

        end

        def component_count_in_debug(debug_xcodeproj)
          count = debug_xcodeproj.groups.length
          if count >= 2
            return count - 2
          else
            UI.puts "获取component的个数可能发成错误"
          end
          return count
        end

        def add_debug_to_workspace()
          # 获取主工程的名字。
          if File.exist? @workspace_name
            workspace = Xcodeproj::Workspace.new_from_xcworkspace @workspace_name
          else
            UI.puts "找不到对应的workspace: #{@workspace_name}，请检查。"
            exit 1
          end
          if !workspace.schemes.values.include? File.realdirpath @debug_path
            workspace << @debug_path
            workspace.save_as @workspace_name
          end
        end

        def remove_debug_from_workspace()
          if File.exist? @workspace_name
            workspace = Xcodeproj::Workspace.new_from_xcworkspace @workspace_name
          else
            UI.puts "找不到对应的workspace: #{@workspace_name}，请检查。"
            exit 1
          end
          if workspace.schemes.values.include? File.realdirpath @debug_path
            workspace >> @debug_path
            workspace.save_as @workspace_name
          end
        end

      end
    end
  end
end


