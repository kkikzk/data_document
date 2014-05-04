# -*- encoding: utf-8 -*-
require 'src_lexer'

#
# Open class of Array class
#
class Array
  def accept(io, visitor)
    each {|e| visitor.call(io, e)}
  end
end

module DataDocument
  #
  # Parse result of data documents
  #
  class ParseResult
    #
    # An array of EnumData class
    #
    attr_reader :enums

    #
    # An array of StructData class
    #
    attr_reader :structs

    #
    # initialize
    #
    def initialize
      @enums = []
      @structs = []
    end

    #
    # Add a enum definition
    #
    # _enum_ :: a definition of enum
    #
    def add_enum(enum)
      @enums.push(enum)
    end

    #
    # Add a struct definition
    #
    # _struct_ :: a definition of struct
    #
    def add_struct(struct)
      @structs.push(struct)
    end
  end

  #
  # Definition of a struct
  #
  class StructData
    #
    # A struct name
    #
    attr_reader :name

    #
    # An array of attribute
    # Supports the attributes below
    #* attr_namespace
    #* attr_name
    #
    attr_reader :attributes

    #
    # A base type of a struct
    #
    attr_reader :base_type

    #
    # An array of StructElement class
    #
    attr_reader :elements

    def initialize(name, attributes, base_type, elements)
      @name = name
      @attributes = attributes
      @base_type = base_type
      @elements = elements
    end
  end

  class StructElement
    attr_reader :name, :attributes, :data_type, :conditions, :count, :default_value 
    def initialize(name, attributes, data_type, conditions, count, default_value)
      @name = name
      @attributes = attributes
      @data_type = data_type
      @conditions = conditions
      @count = count
      @default_value = default_value
    end
  end

  class EnumData
    attr_reader :name, :attributes, :elements
    def initialize(name, attributes, elements)
      @name = name
      @attributes = attributes
      @elements = elements
    end
  end

  class EnumElement
    attr_reader :name, :attributes, :value
    def initialize(name, attributes, value)
      @name = name
      @attributes = attributes
      @value = value
    end
  end

  class Attribute
    attr_reader :type, :value
    def initialize(type, value)
      @type = type
      @value = value
    end
  end

  class DocToCSharp
    class EnumDefinitionError < StandardError; end
    class StructDefinitionError < StandardError; end
    attr_reader :definitions
    def initialize(definitions)
      @definitions = definitions
    end
    def build(io)
      class << io
        attr_accessor :indent_level
        alias :old_puts :puts
        def puts(str)
          if str.empty?
            puts_core str
          else
            str.each_line{|line| puts_core line.chomp}
          end
        end
        def puts_core(str)
          stripped = str.strip
          if 1 <= stripped.length && stripped[0] == '}' && 1 <= @indent_level
            old_puts ('    ' * (@indent_level - 1)) + str.strip
          else
            old_puts ('    ' * @indent_level) + str.strip
          end
          @indent_level = @indent_level + stripped.count('{') - stripped.count('}')
        end
      end
      io.indent_level = 0
      DocToCSharp.make_using(io)
      io.puts ''
      make_enums(io)
      make_structs(io)
      DocToCSharp.make_validator(io)
      io.puts ''
      DocToCSharp.make_indexer(io)
    end
    def self.make_using(io)
      io.puts <<-'EOS'
        using System;
        using System.Collections.Generic;
        using System.Diagnostics;
        using System.IO;
      EOS
    end
    def make_enums(io)
      @definitions.enums.accept(io, DocToCSharp.method(:visit_enum_definition))
    end
    def make_structs(io)
      @definitions.structs.accept(io, DocToCSharp.method(:visit_struct_definition))
    end
    def self.collect_attributes(attributes, type)
      attributes.nil? ? [] : attributes.select{|a| a.type == type}.map{|a| a.value[1..-2]}
    end
    def self.make_namespace(namespaces)
      namespaces.push 'DataDocument' if namespaces.length.zero?
      return namespaces
    end
    def self.visit_enum_definition(io, enum)
      namespaces = collect_attributes(enum.attributes, 'attr_namespace')
      types = collect_attributes(enum.attributes, 'attr_type')
      raise EnumDefinitionError, 'multiple enum type definition => enum ' + enum.name if 1 < types.length
      make_namespace(namespaces).each{|namespace| io.puts 'namespace ' + namespace; io.puts '{'}
      make_summary(io, enum)
      io.puts 'public enum ' + enum.name + (types.length.zero? ? '' : ' : ' + to_csharp_type(types[0]))
      io.puts '{'
      enum.elements.accept(io, method(:visit_enum_member))
      io.puts '}'
      namespaces.each{|namespace| io.puts '}'}
      io.puts ''
    end
    def self.make_summary(io, target)
      names = collect_attributes(target.attributes, 'attr_name')
      if names.length.nonzero?
        summary = <<-'EOS'
          /// <summary>
          /// %s
          /// </summary>
        EOS
        io.puts summary % names.join(' ')
      end
    end
    def self.visit_enum_member(io, element)
      make_summary(io, element)
      io.puts '' + element.name + ' = ' + element.value + ','
    end
    def self.visit_struct_definition(io, struct)
      namespaces = collect_attributes(struct.attributes, 'attr_namespace')
      make_namespace(namespaces).each{|namespace| io.puts 'namespace ' + namespace; io.puts '{'}
      make_summary(io, struct)
      io.puts 'public class ' + struct.name + (struct.base_type.nil? ? '' : ' : ' + struct.base_type)
      io.puts '{'
      struct.elements.accept(io, method(:visit_struct_member))
      io.puts ''
      struct.elements.accept(io, method(:visit_struct_accessor))
      visit_struct_constructor(io, struct)
      io.puts '}'
      namespaces.each{|namespace| io.puts '}'}
      io.puts ''
    end
    def self.make_construction_statement(element)
      if element.data_type == 'string' && element.count == '1' && element.default_value.nil?
        ' = String.Empty'
      elsif primitive?(element.data_type) && element.count == '1' && !element.default_value.nil?
        ' = ' + element.default_value
      elsif primitive?(element.data_type) && element.count == '1'
        ''
      else
        is_fixed_array = !numeric?(element.count) || (numeric?(element.count) && (element.count.to_i != 1 && element.count.to_i != -1))
        ' = new ' + to_concrete_data_type(element) + '(' + (is_fixed_array ? element.count : '') + ')'
      end
    end
    def self.numeric?(target)
      Integer(target)
        true
      rescue ArgumentError
        false
    end
    def self.to_concrete_data_type(element)
      template = if numeric?(element.count) && element.count.to_i == 1
        '%s'
      elsif numeric?(element.count) && element.count.to_i == -1
        'List<%s>'
      elsif primitive?(element.data_type)
        'DataDocument.Indexer<%s>'
      else
        'DataDocument.ClassIndexer<%s>'
      end
      sprintf(template, to_csharp_type(element.data_type))
    end
    def self.validate_struct_member(element)
      raise StructDefinitionError, 'invalid element count => element ' + element.name if numeric?(element.count) && (element.count.to_i == 0 || element.count.to_i <= -2)
    end
    def self.visit_struct_member(io, element)
      validate_struct_member element
      io.puts 'private ' + to_concrete_data_type(element) + ' ' +
        to_variable_name(element.name) + make_construction_statement(element) + ';'
    end
    def self.visit_struct_accessor(io, element)
      make_summary(io, element)
      io.puts 'public ' + to_concrete_data_type(element) + ' ' + element.name
      io.puts '{'
      io.puts '    [DebuggerStepThrough]'
      if element.conditions.nil? || (numeric?(element.count) && 2 <= element.count.to_i)
        io.puts '    set { ' + to_variable_name(element.name) + ' = value; }'
      else
        validation_type = to_csharp_type(element.data_type == 'string' ? 'int32' : element.data_type)
        validation_data_getter = (element.data_type == 'string' ? '() => value.Length' : '() => value')
        io.puts '    set {'
        io.puts '        Tuple<' + validation_type + ', ' + validation_type + '>[] conditions = new Tuple<' + validation_type + ', ' + validation_type + '>[] {'
        element.conditions.each do |c|
          range = to_range(c, element.data_type)
          io.puts '            new Tuple<' + validation_type + ', ' + validation_type + '>(' + range[0] + ', ' + range[1] + '),' 
        end
        io.puts '        };'
        io.puts '        new DataDocument.RangeValidator<' + validation_type + '>(conditions).Validate(' + validation_data_getter + ');'
        io.puts '        ' + to_variable_name(element.name) + ' = value;'
        io.puts '    }'
      end
      io.puts '    [DebuggerStepThrough]'
      io.puts '    get { return ' + to_variable_name(element.name) + '; }'
      io.puts '}'
      io.puts ''
    end
    def self.visit_struct_constructor(io, struct)
      io.puts '/// <summary>'
      io.puts '/// Constructor'
      io.puts '/// </summary>'
      io.puts 'public ' + struct.name + '()'
      io.puts '{'
      struct.elements.accept(io, method(:visit_struct_construct_element))
      io.puts '}'
    end
    def self.visit_struct_construct_element(io, element)
      if numeric?(element.count) && 2 <= element.count.to_i
        io.puts '// ' + element.name
        if primitive?(element.data_type) && !element.default_value.nil?
          if !element.conditions.nil?
            validation_type = to_csharp_type(element.data_type == 'string' ? 'int32' : element.data_type)
            io.puts '    Tuple<' + validation_type + ', ' + validation_type + '>[] conditions' + element.name + ' = new Tuple<' + validation_type + ', ' + validation_type + '>[] {'
            element.conditions.each do |c|
              range = to_range(c, element.data_type)
              io.puts '        new Tuple<' + validation_type + ', ' + validation_type + '>(' + range[0] + ', ' + range[1] + '),'
            end
            io.puts '    };'
            io.puts '    ' + to_variable_name(element.name) + '.Validator = new DataDocument.RangeValidator<' + validation_type + '>(conditions' + element.name + ')'';'
          end
          io.puts '    for (Int32 i = 0; i < ' + element.count + '; ++i)'
          io.puts '    {'
          io.puts '        ' + to_variable_name(element.name) + '[i] = ' + element.default_value + ';'
          io.puts '    }'
        elsif !primitive?(element.data_type)
          io.puts '    for (Int32 i = 0; i < ' + element.count + '; ++i)'
          io.puts '    {'
          io.puts '        ' + to_variable_name(element.name) + '[i] = new ' + element.data_type + '();'
          io.puts '    }'
        end
      elsif !element.default_value.nil?
        io.puts '// ' + element.name
        io.puts '    ' + to_variable_name(element.name) + ' = ' + element.default_value + ';'
      end
    end
    def self.primitive?(data_type)
      to_csharp_type(data_type) != data_type
    end
    def self.to_csharp_type(data_type)
      case data_type
      when 'int64'
        'Int64'
      when 'int32'
        'Int32'
      when 'int16'
        'Int16'
      when 'int8'
        'SByte'
      when 'uint64'
        'UInt64'
      when 'uint32'
        'UInt32'
      when 'uint16'
        'UInt16'
      when 'uint8'
        'Byte'
      when 'bool'
        'Boolean'
      when 'string'
        'String'
      when 'decimal'
        'Decimal'
      when 'float'
        'Single'
      when 'double'
        'Double'
      when 'char'
        'Char'
      else
        data_type
      end
    end
    def self.to_range(condition, data_type)
      range = condition.split('..')
      if range[0] == 'Min'
        range[0] = to_csharp_type(data_type) + '.MinValue'
      elsif range[0] == 'Max'
        range[0] = to_csharp_type(data_type) + '.MaxValue'
      end
      if range[1] == 'Min'
        range[1] = to_csharp_type(data_type) + '.MinValue'
      elsif range[1] == 'Max'
        range[1] = to_csharp_type(data_type) + '.MaxValue'
      end
      return range
    end
    def self.make_validator(io)
      io.puts <<-'EOS'
        namespace DataDocument
        {
            internal class RangeValidator<T>
                where T : IComparable
            {
  		          private IEnumerable<Tuple<T, T>> _ranges;
  		          public RangeValidator(IEnumerable<Tuple<T, T>> ranges)
  		          {
  		              _ranges = ranges;
  		          }
                public void Validate(Func<T> valueGetter)
  		          {
                    T value = valueGetter();
  		              foreach (var range in _ranges)
  		              {
  		                  if ((range.Item1.CompareTo(value) <= 0) && (value.CompareTo(range.Item2) <= 0))
  		                  {
  		                      return;
  		                  }
  		              }
  		              throw new ArgumentException();
  		          }
            }
        }
      EOS
    end
    def self.make_indexer(io)
      io.puts <<-'EOS'
        namespace DataDocument
        {
            public class Indexer<T>
                where T : IComparable
            {
                private T[] _array;
                public DataDocument.RangeValidator<T> Validator { set; get; }
                public T this[int i]
                {
                    set
                    {
                        if (Validator != null) Validator.Validate(() => value)
                        _array[i] = value;
                    }
                    get { return _array[i]; }
                }
                public Indexer(int count)
                {
                    _array = new T[count];
                }
            }
        }

        namespace DataDocument
        {
            public class ClassIndexer<T>
                where T : class
            {
                private T[] _array;
                public T this[int i]
                {
                    set
                    {
                        if (value == null) throw new ArgumentNullException();
                        _array[i] = value;
                    }
                    get { return _array[i]; }
                }
                public ClassIndexer(int count)
                {
                     _array = new T[count];
                }
            }
        }
      EOS
    end
    def self.to_variable_name(name)
      '_' + name
    end
  end
end
