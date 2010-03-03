require 'dub/argument'
require 'dub/entities_unescape'

module Dub
  class Function
    include Dub::EntitiesUnescape
    attr_reader :arguments, :prefix, :overloaded_index, :return_value, :xml, :parent
    attr_accessor :gen, :name

    def initialize(parent, name, xml, prefix = '', overloaded_index = nil)
      @parent, @name = parent, name
      @xml, @prefix, @overloaded_index = xml, prefix, overloaded_index
      parse_xml

      if constructor?
        @return_value = Argument.new(self, (Hpricot::XML("<type>#{name} *</type>")/''))
      end
    end

    def bind(generator)
      @gen = generator.function_generator
    end

    def to_s
      generator.function(self)
    end

    def generator
      @gen || (@parent && @parent.function_generator)
    end

    def klass
      @parent.kind_of?(Klass) ? @parent : nil
    end

    def member_method?
      !klass.nil?
    end

    def constructor?
      @name == @parent.name
    end

    alias gen generator

    def source
      loc = (@xml/'location').first.attributes
      "#{loc['file'].split('/')[-3..-1].join('/')}:#{loc['line']}"
    end

    def original_signature
      unescape "#{(@xml/'definition').innerHTML}#{(@xml/'argsstring').innerHTML}"
    end

    def has_default_arguments?
      return @has_defaults if defined?(@has_defaults)
      @has_defaults = !@arguments.detect {|a| a.has_default? }.nil?
    end

    def has_array_arguments?
      return @has_array_arguments if defined?(@has_array_arguments)
      @has_array_arguments = !@arguments.detect {|a| a.array_suffix }.nil?
    end

    def vararg?
      @arguments.last && @arguments.last.vararg?
    end

    def inspect
      "#<Function #{@prefix}_#{@name}(#{@arguments.inspect[1..-2]})>"
    end

    def <=>(other)
      name <=> other.name
    end

    # ====== these methods are alias to
    # generator methods on this object

    def method_name(overloaded_index = nil)
      gen.method_name(self, overloaded_index)
    end

    # =================================

    private
      def parse_xml
        @arguments = []

        (@xml/'param').each_with_index do |arg, i|
          @arguments << Argument.new(self, arg, i + 1)
        end

        raw_type = (@xml/'/type').innerHTML
        if raw_type.strip == ''
          # no return type
        else
          arg = Argument.new(self, (@xml/'/type'))
          @return_value = arg unless arg.create_type =~ /void\s*$/
        end
      end
  end
end # Namespace
