require 'xcodeproj'
require 'cocoapods'

`cd /Users/handa/Documents/lianjia/B/lianjia_im;pod jsource add flutter_boost`

#`cd /Users/handa/Downloads/Example;pod jsource clean LJRefresh --cache`
#`cd /Users/handa/Documents/lianjia/C/lianjia_ios_platc;pod jsource add LJBaseToolKit`
#`cd /Users/handa/Downloads/Example;pod jsource add LJRefresh http://gerrit.lianjia.com/mobile_ios/LJRefresh`
#

# `cd /Users/handa/Documents/test/testZSource;pod jsource list`

# `cd /Users/handa/Documents/test/testZSource;pod jsource clean LJCache`
#
#`cd /Users/handa/Documents/lianjia/LJBaseContext/Example; pod update`

# require 'cocoapods-core'
# spec = Pod::Specification.from_file("/Users/handa/Documents/lianjia/LJPlatBPodSpecs/LJMessengerSDK/2.30.3.0/LJMessengerSDK.podspec")


def addFilesToGroup(project, aTarget, aGroup)
  Dir.foreach(aGroup.real_path) do |entry|
    filePath = File.join(aGroup.real_path, entry)
    # 过滤目录和.DS_Store文件
    if !File.directory?(filePath) && entry != ".DS_Store" then
          # 向group中增加文件引用
          fileReference = aGroup.new_reference(filePath)
          # 如果不是头文件则继续增加到Build Phase中，PB文件需要加编译标志
      if filePath.to_s.end_with?("pbobjc.m", "pbobjc.mm") then
        aTarget.add_file_references([fileReference], '-fno-objc-arc')
      elsif filePath.to_s.end_with?(".m", ".mm", ".cpp") then
        aTarget.source_build_phase.add_file_reference(fileReference, true)
      elsif filePath.to_s.end_with?(".plist") then
        aTarget.resources_build_phase.add_file_reference(fileReference, true)
      end
      # 目录情况下, 递归添加
    elsif File.directory?(filePath) && entry != '.' && entry != '..' then
      hierarchy_path = aGroup.hierarchy_path[1, aGroup.hierarchy_path.length]
      subGroup = project.main_group.find_subpath(hierarchy_path + '/' + entry, true)
      subGroup.set_source_tree('<group>')
      subGroup.set_path(aGroup.real_path + entry)
      addFilesToGroup(project, aTarget, subGroup)
    end
  end
end



def addFilesToGroupNew(project, aGroup)
  Dir.foreach(aGroup.real_path) do |entry|
    filePath = File.join(aGroup.real_path, entry)
    # 过滤目录和.DS_Store文件
    if !File.directory?(filePath) && entry != ".DS_Store" then
      # 向group中增加文件引用
      aGroup.new_reference(filePath)
      # 目录情况下, 递归添加
    elsif File.directory?(filePath) && entry != '.' && entry != '..' then
      hierarchy_path = aGroup.hierarchy_path[1, aGroup.hierarchy_path.length]
      subGroup = project.main_group.find_subpath(hierarchy_path + '/' + entry, true)
      subGroup.set_source_tree('<group>')
      subGroup.set_path(aGroup.real_path + entry)
      addFilesToGroupNew(project,subGroup)
    end
  end
end

 # 添加Pods/JSources.xcodeproj

 # 在Pods/JSources.xcodeproj 添加group Pods
 #
 # 在Pods目录添加每个组件的调试信息。
 #
 # 如果不指定-u 则用的是本地的源码，如果指定-u，则用的是网络里的源码。
 #
 #
#
#project_path = '/Users/handa/Documents/lianjia/cocoapods-jsource/test.xcodeproj'
#project = ""
#if File.exist? project_path
#  project = Xcodeproj::Project.open(project_path)
#else
#  project = Xcodeproj::Project.new(project_path)
#end
#
#path = "/var/folders/qb/qcgb09sx36l65jj4vglxz3nw0000gq/T/cocoapods-uru6ziwd/Pods/LJRefresh/LJRefresh/"
#exampleGroup=project.main_group.new_group("LJRefresh", path)
#exampleGroup.set_source_tree('<absolute>')
##target = project.new_target(:application,"LJRefresh",:ios)
#addFilesToGroupNew(project, exampleGroup)
#
#
#
#project.save
#
#
#new_path = "/Users/handa/Downloads/Example/"
#file = "Example.xcworkspace"
#Dir.chdir(new_path)
##workspace = Xcodeproj::Workspace.new_from_xcworkspace(file)
#
#ref = Xcodeproj::Workspace::FileReference.new(project_path)
##if workspace.include? ref
##  print "already included"
##else
##  workspace << project_path
##end
##workspace.save_as(file)
#
#new_path = "/Users/handa/Downloads/Example/Pods/Pods.xcodeproj"
#if File.exist? new_path
#  pod_project = Xcodeproj::Project.open(new_path)
#end


#
#`mkdir Pods/JSources`
#jsource_group=pod_project.main_group.new_group("JSources", "./Pods/JSources")
#
#
#jsource_group.add_referrer(ref)
#
#
#
#pod_project.save



#config = Pod::Config.instance
#installer = Pod::Installer.new(config.sandbox, config.podfile, config.lockfile)
#installer.repo_update = false
#installer.update = false
#installer.generated_pod_targets
