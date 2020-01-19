require 'xcodeproj'
require "rexml/xpath"

module Xcodeproj
  # Provides support for generating, reading and serializing Xcode Workspace
  # documents.
  #
  class Workspace

    # removes a new path to the list of the of projects contained in the
    # workspace.
    # @param [String, Xcodeproj::Workspace::FileReference] path_or_reference
    #        A string or Xcode::Workspace::FileReference containing a path to an Xcode project
    #
    # @raise [ArgumentError] Raised if the input is neither a String nor a FileReference
    #
    # @return [void]
    #
    def >>(path_or_reference)
      return unless @document && @document.respond_to?(:root)
      debug_element = nil
      @document.elements.each("*/FileRef") do |element|
        location = element.attributes["location"]
        if location == "group:#{path_or_reference}"
          debug_element = element
        end
      end
      @document.root.delete_element(debug_element)
      load_schemes_from_project File.expand_path(path_or_reference)
    end
  end

end

