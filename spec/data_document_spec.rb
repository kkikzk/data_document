# -*- encoding: utf-8 -*-
require_relative './spec_helper'

module SrcLexer
  class CSharpLexer < Lexer
    def ==(other_object)
      if other_object.instance_of? String
        lexer = CSharpLexer.new
        lexer.analyze(other_object)
        tokens = lexer.instance_variable_get :@tokens
        (0...(@tokens.length < tokens.length ? @tokens.length : tokens.length)).each do |index|
          if @tokens[index][0] != tokens[index][0]
            expected = tokens[index][0]
            actual = @tokens[index][0]
            actual_tokens = @tokens[index..-1].map{|e| e[0]}.join(' ')
            raise 'mismatch token [index=' + index.to_s + '] expected="' + expected + '", actual="' + actual + '" :::: actual_tokens => ' + actual_tokens
          end
        end
        raise 'mismatch token [expected is longer then actual] :::: rest expected_token => ' + tokens[@tokens.length..-1].map{|e| e[0]}.join(' ') if @tokens.length < tokens.length
        raise 'mismatch token [actual is longer then expected] :::: rest actual_token => ' + @tokens[tokens.length..-1].map{|e| e[0]}.join(' ') if tokens.length < @tokens.length
        return true
      else
        super
      end
    end
  end
end

describe DataDocument do
  it 'should have a version number' do
    expect(DataDocument::VERSION).not_to be_nil
  end
end

describe DataDocument::DocToCSharp, 'when enum defined' do
  it 'should recognize the definition' do
    # arrange
    elements = []
    elements.push DataDocument::EnumElement.new('First', nil, '1')
    elements.push DataDocument::EnumElement.new('Second', nil, '2')
    definition = []
    definition.push DataDocument::EnumData.new('Enum', nil, elements)
    # act
    io = StringIO.new('result', 'r+')
    definition.accept(io, DataDocument::DocToCSharp.method(:visit_enum_definition))
    io.rewind
    # assert
    expect(
      SrcLexer::CSharpLexer.new.analyze(io.read)    
    ).to eq(<<-'EOS'
      namespace DataDocument {
        public enum Enum {
          First = 1,
          Second = 2,
        }
      }
      EOS
    )
  end
end

describe DataDocument::DocToCSharp, 'when enum defined with attributes' do
  it 'should recognize namespace attributes' do
    # arrange
    elements = []
    elements.push DataDocument::EnumElement.new('First', nil, '1')
    attributes = []
    attributes.push DataDocument::Attribute.new('attr_namespace', '"Hoge"')
    attributes.push DataDocument::Attribute.new('attr_namespace', '"Huga"')
    definition = []
    definition.push DataDocument::EnumData.new('Enum', attributes, elements)
    # act
    io = StringIO.new('result', 'r+')
    definition.accept(io, DataDocument::DocToCSharp.method(:visit_enum_definition))
    io.rewind
    # assert
    expect(
      SrcLexer::CSharpLexer.new.analyze(io.read)
    ).to eq(<<-'EOS'
      namespace Hoge { namespace Huga {
        public enum Enum {
          First = 1,
        }
      }}
      EOS
    )
  end
  it 'should recognize a enum type attribute' do
    # arrange
    elements = []
    elements.push DataDocument::EnumElement.new('First', nil, '1')
    attributes = []
    attributes.push DataDocument::Attribute.new('attr_type', '"int16"')
    definition = []
    definition.push DataDocument::EnumData.new('Enum', attributes, elements)
    # act
    io = StringIO.new('result', 'r+')
    definition.accept(io, DataDocument::DocToCSharp.method(:visit_enum_definition))
    io.rewind
    # assert
    expect(
      SrcLexer::CSharpLexer.new.analyze(io.read)
    ).to eq(<<-'EOS'
      namespace DataDocument {
        public enum Enum : Int16 {
          First = 1,
        }
      }
      EOS
    )
  end
  it 'should raise a error if multiple enum type defined' do
    # arrange
    elements = []
    elements.push DataDocument::EnumElement.new('First', nil, '1')
    attributes = []
    attributes.push DataDocument::Attribute.new('attr_type', 'int16')
    attributes.push DataDocument::Attribute.new('attr_type', 'int32')
    definition = []
    definition.push DataDocument::EnumData.new('Enum', attributes, elements)
    # act & assert
    io = StringIO.new('result', 'r+')
    expect {
      definition.accept(io, DataDocument::DocToCSharp.method(:visit_enum_definition))
    }.to raise_error(DataDocument::DocToCSharp::EnumDefinitionError)
  end
  it 'should ignore unknown attributes' do
    # arrange
    elements = []
    elements.push DataDocument::EnumElement.new('First', nil, '1')
    attributes = []
    attributes.push DataDocument::Attribute.new('attr_dummy', 'Dummy')
    definition = []
    definition.push DataDocument::EnumData.new('Enum', attributes, elements)
    # act
    io = StringIO.new('result', 'r+')
    definition.accept(io, DataDocument::DocToCSharp.method(:visit_enum_definition))
    io.rewind
    # assert
    expect(
      SrcLexer::CSharpLexer.new.analyze(io.read)
    ).to eq(<<-'EOS'
      namespace DataDocument {
        public enum Enum {
          First = 1,
        }
      }
      EOS
    )
  end
end

describe DataDocument::DocToCSharp, 'when struct defined' do
  it 'should make variables' do
    # arrange
    definition = []
    definition.push DataDocument::StructElement.new('Data', nil, 'string', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data2', nil, 'string', nil, "1", '"Hoge"')
    definition.push DataDocument::StructElement.new('Data3', nil, 'int64', nil, "1", '2')
    definition.push DataDocument::StructElement.new('Data4', nil, 'int32', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data5', nil, 'int16', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data6', nil, 'int8', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data7', nil, 'uint64', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data8', nil, 'uint32', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data9', nil, 'uint16', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data10', nil, 'uint8', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data11', nil, 'bool', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data12', nil, 'decimal', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data13', nil, 'float', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data14', nil, 'double', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data15', nil, 'char', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data16', nil, 'int32', nil, "-1", nil)
    definition.push DataDocument::StructElement.new('Data17', nil, 'HogeClass', nil, "1", nil)
    definition.push DataDocument::StructElement.new('Data18', nil, 'HogeClass', nil, "2", nil)
    definition.push DataDocument::StructElement.new('Data19', nil, 'int32', nil, "3", nil)
    definition.push DataDocument::StructElement.new('Data20', nil, 'int32', nil, "Data19", nil)
    # act
    io = StringIO.new('result', 'r+')
    definition.accept(io, DataDocument::DocToCSharp.method(:visit_struct_member))
    io.rewind
    # assert
    expect(
      SrcLexer::CSharpLexer.new.analyze(io.read)
    ).to eq(<<-'EOS'
      private String _Data = String.Empty;
      private String _Data2 = "Hoge";
      private Int64 _Data3 = 2;
      private Int32 _Data4;
      private Int16 _Data5;
      private SByte _Data6;
      private UInt64 _Data7;
      private UInt32 _Data8;
      private UInt16 _Data9;
      private Byte _Data10;
      private Boolean _Data11;
      private Decimal _Data12;
      private Single _Data13;
      private Double _Data14;
      private Char _Data15;
      private List<Int32> _Data16 = new List<Int32>();
      private HogeClass _Data17 = new HogeClass();
      private DataDocument.ClassIndexer<HogeClass> _Data18 = new DataDocument.ClassIndexer<HogeClass>(2);
      private DataDocument.Indexer<Int32> _Data19 = new DataDocument.Indexer<Int32>(3);
      private DataDocument.Indexer<Int32> _Data20 = new DataDocument.Indexer<Int32>(Data19);
      EOS
    )
  end
  it 'should make accessors' do
    # arrange
    definition = []
    definition.push DataDocument::StructElement.new('Data', nil, 'int32', nil, '1', nil)
    # act
    io = StringIO.new('result', 'r+')
    definition.accept(io, DataDocument::DocToCSharp.method(:visit_struct_accessor))
    io.rewind
    # assert
    expect(
      SrcLexer::CSharpLexer.new.analyze(io.read)
    ).to eq(<<-'EOS'
      public Int32 Data {
        [DebuggerStepThrough]
        set { _Data = value; }
        [DebuggerStepThrough]
        get { return _Data; }
      }
      EOS
    )
  end
  it 'should make range validatable accessors' do
    # arrange
    definition = []
    definition.push DataDocument::StructElement.new('Data', nil, 'int32', ['Min..Max'], '1', nil)
    definition.push DataDocument::StructElement.new('Data2', nil, 'string', ['0..10', '15..20'], '1', nil)
    # act
    io = StringIO.new('result', 'r+')
    definition.accept(io, DataDocument::DocToCSharp.method(:visit_struct_accessor))
    io.rewind
    # assert
    expect(
      SrcLexer::CSharpLexer.new.analyze(io.read)
    ).to eq(<<-'EOS'
      public Int32 Data {
        [DebuggerStepThrough]
        set {
          Tuple<Int32, Int32>[] conditions = new Tuple<Int32, Int32>[] {
            new Tuple<Int32, Int32>(Int32.MinValue, Int32.MaxValue),
          };
          new DataDocument.RangeValidator<Int32>(conditions).Validate(() => value);
          _Data = value;
        }
        [DebuggerStepThrough]
        get { return _Data; }
      }
      public String Data2 {
        [DebuggerStepThrough]
        set {
          Tuple<Int32, Int32>[] conditions = new Tuple<Int32, Int32>[] {
            new Tuple<Int32, Int32>(0, 10),
            new Tuple<Int32, Int32>(15, 20),
          };
          new DataDocument.RangeValidator<Int32>(conditions).Validate(() => value.Length);
          _Data2 = value;
        }
        [DebuggerStepThrough]
        get { return _Data2; }
      }
      EOS
    )
  end
  it 'should make range validatable object at constructor' do
    # arrange
    definition = []
    definition.push DataDocument::StructElement.new('Data', nil, 'int32', ['0..5'], '2', '1')
    # act
    io = StringIO.new('result', 'r+')
    definition.accept(io, DataDocument::DocToCSharp.method(:visit_struct_construct_element))
    io.rewind
    # assert
    expect(
      SrcLexer::CSharpLexer.new.analyze(io.read)
    ).to eq(<<-'EOS'
      Tuple<Int32, Int32>[] conditionsData = new Tuple<Int32, Int32>[] {
        new Tuple<Int32, Int32>(0, 5),
      };
      _Data.Validator = new DataDocument.RangeValidator<Int32>(conditionsData);
      for (Int32 i = 0; i < 2; ++i) {
        _Data[i] = 1;
      }
      EOS
    )
  end
  it 'should make initialize statement at constructor' do
    # arrange
    definition = []
    definition.push DataDocument::StructElement.new('Data', nil, 'int32', nil, '1', '1')
    definition.push DataDocument::StructElement.new('Data2', nil, 'int32', nil, '2', '1')
    definition.push DataDocument::StructElement.new('Data3', nil, 'HogeClass', nil, '2', nil)
    # act
    io = StringIO.new('result', 'r+')
    definition.accept(io, DataDocument::DocToCSharp.method(:visit_struct_construct_element))
    io.rewind
    # assert
    expect(
      SrcLexer::CSharpLexer.new.analyze(io.read)
    ).to eq(<<-'EOS'
      _Data = 1;
      for (Int32 i = 0; i < 2; ++i) {
        _Data2[i] = 1;
      }
      for (Int32 i = 0; i < 2; ++i) {
        _Data3[i] = new HogeClass();
      }
      EOS
    )
  end
  it 'should raise a error with 0 element count' do
    # arrange
    definition = []
    definition.push DataDocument::StructElement.new('Data', nil, 'int32', nil, '0', nil)
    # act & assert
    io = StringIO.new('result', 'r+')
    expect {
      definition.accept(io, DataDocument::DocToCSharp.method(:visit_struct_member))
    }.to raise_error(DataDocument::DocToCSharp::StructDefinitionError)
  end
  it 'should raise a error with a element count under -1' do
    # arrange
    definition = []
    definition.push DataDocument::StructElement.new('Data', nil, 'int32', nil, '-2', nil)
    # act & assert
    io = StringIO.new('result', 'r+')
    expect {
      definition.accept(io, DataDocument::DocToCSharp.method(:visit_struct_member))
    }.to raise_error(DataDocument::DocToCSharp::StructDefinitionError)
  end
  it 'should recognize the definition' do
    pending
    # arrange
    elements = []
    elements.push DataDocument::StructElement.new('Data', nil, 'int32', nil, nil, nil)
    definition = []
    definition.push DataDocument::StructData.new('Struct', nil, nil, elements)
    # act
    io = StringIO.new('result', 'r+')
    definition.accept(io, DataDocument::DocToCSharp.method(:visit_struct_definition))
    io.rewind
    # assert
    expect(
      SrcLexer::CSharpLexer.new.analyze(io.read)
    ).to eq(
      'namespace DataDocument {' +
      '    public class Struct {' +
      '        First = 1,' +
      '    }' +
      '}'
    )
  end
end

describe DataDocument::DocParser, 'with enum definitions' do
  it 'should recognize the definitions' do
    pending
    parser_result = DataDocument::DocParser.new.parse('enum Enum { First = 1 }')
    csharp_source_code = DataDocument::DocToCSharp.new(parser_result).build
    SrcLexer::CSharpLexer.new.analyze(csharp_source_code).should ==
      'using System;' +
      'using System.Collections.Generic;' +
      'using System.Diagnostics;' +
      'using System.IO;' +
      'namespace DataDocument {' +
      '    public enum Enum {' +
      '        First = 1,' +
      '    }' +
      '}'
  end
end

describe DataDocument::DocParser, 'with struct definitions' do
  it 'should recognize the definitions' do
    pending
    parser_result = DataDocument::DocParser.new.parse('struct Struct { int Data = 1; }')
    csharp_source_code = DataDocument::DocToCSharp.new(parser_result).build
    expect(
      SrcLexer::CSharpLexer.new.analyze(csharp_source_code)
    ).to eq(
      'using System;' +
      'using System.Collections.Generic;' +
      'using System.Diagnostics;' +
      'using System.IO;' +
      'namespace DataDocument {' +
      '    public class Struct {' +
      '        private int _Data = 1;' +
      '        public int Data { set { _Data = value; } get { return _Data; } }' +
      '        public Struct() {' +
      '        }' +
      '    }' +
      '}'
    )
  end
end
