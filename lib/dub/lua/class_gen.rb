
require 'dub/generator'
require 'erb'

module Dub
  module Lua
    class ClassGen < Dub::Generator
      def initialize
        @class_template = ::ERB.new(File.read(File.join(File.dirname(__FILE__), 'class.cpp.erb')))
      end

      def klass(klass)
        @class = klass
        @class_template.result(binding)
      end

      def function_generator
        Lua.function_generator
      end

      def method_registration
        member_methods = @class.members.map do |method|
          "{%-20s, #{method.method_name}}" % method.name.inspect
        end

        member_methods << "{%-20s, #{@class.tostring_name}}" % "__tostring".inspect
        member_methods << "{%-20s, #{@class.destructor_name}}" % "__gc".inspect

        member_methods.join(",\n")
      end

      def namespace_methods_registration
        ([@class.name] + @class.alias_names).map do |name|
          "{%-20s, #{@class.constructor.method_name(0)}}" % name.inspect
        end.join(",\n")
      end

      def members_list(all_members)
        list = all_members.map do |member_or_group|
          if member_or_group.kind_of?(Array)
            members_list(member_or_group)
          elsif ignore_member?(member_or_group)
            nil
          else
            member_or_group
          end
        end

        list.compact!
        list == [] ? nil : list
      end

      def ignore_member?(member)
        member.name =~ /^~/           || # do not build constructor
        member.name =~ /^operator/    || # no conversion operators
        member.return_type =~ />$/    || # no complex return types
        member.return_type_is_native_pointer ||
        member.original_signature =~ />/ # no complex types in signature
      end
    end
  end
end
