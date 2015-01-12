### (From: https://github.com/ruby/ruby/blob/trunk/lib/prettyprint.rb)
#
# This class implements a pretty printing algorithm. It finds line breaks and
# nice indentations for grouped structure.
#
# By default, the class assumes that primitive elements are strings and each
# byte in the strings have single column in width. But it can be used for
# other situations by giving suitable arguments for some methods:
# * newline object and space generation block for PrettyPrint.new
# * optional width argument for PrettyPrint#text
# * PrettyPrint#breakable
#
# There are several candidate uses:
# * text formatting using proportional fonts
# * multibyte characters which has columns different to number of bytes
# * non-string formatting
#
# == Bugs
# * Box based formatting?
# * Other (better) model/algorithm?
#
# Report any bugs at http://bugs.ruby-lang.org
#
# == References
# Christian Lindig, Strictly Pretty, March 2000,
# http://www.st.cs.uni-sb.de/~lindig/papers/#pretty
#
# Philip Wadler, A prettier printer, March 1998,
# http://homepages.inf.ed.ac.uk/wadler/topics/language-design.html#prettier
#
# == Author
# Tanaka Akira <akr@fsij.org>
#
class PrettyPrint

  # This is a convenience method which is same as follows:
  #
  #   begin
  #     q = PrettyPrint.new(output, maxwidth, newline, &genspace)
  #     ...
  #     q.flush
  #     output
  #   end
  #
  def PrettyPrint.format(output='', maxwidth=79, newline="\n", genspace=lambda {|n| ' ' * n})
    q = PrettyPrint.new(output, maxwidth, newline, &genspace)
    yield q
    q.flush
    output
  end

  # This is similar to PrettyPrint::format but the result has no breaks.
  #
  # +maxwidth+, +newline+ and +genspace+ are ignored.
  #
  # The invocation of +breakable+ in the block doesn't break a line and is
  # treated as just an invocation of +text+.
  #
  def PrettyPrint.singleline_format(output='', maxwidth=nil, newline=nil, genspace=nil)
    q = SingleLine.new(output)
    yield q
    output
  end

  # Creates a buffer for pretty printing.
  #
  # +output+ is an output target. If it is not specified, '' is assumed. It
  # should have a << method which accepts the first argument +obj+ of
  # PrettyPrint#text, the first argument +sep+ of PrettyPrint#breakable, the
  # first argument +newline+ of PrettyPrint.new, and the result of a given
  # block for PrettyPrint.new.
  #
  # +maxwidth+ specifies maximum line length. If it is not specified, 79 is
  # assumed. However actual outputs may overflow +maxwidth+ if long
  # non-breakable texts are provided.
  #
  # +newline+ is used for line breaks. "\n" is used if it is not specified.
  #
  # The block is used to generate spaces. {|width| ' ' * width} is used if it
  # is not given.
  #
  def initialize(output='', maxwidth=79, newline="\n", &genspace)
    @output = output
    @maxwidth = maxwidth
    @newline = newline
    @genspace = genspace || lambda {|n| ' ' * n}

    @output_width = 0
    @buffer_width = 0
    @buffer = []

    root_group = Group.new(0)
    @group_stack = [root_group]
    @group_queue = GroupQueue.new(root_group)
    @indent = 0
  end

  # The output object.
  #
  # This defaults to '', and should accept the << method
  attr_reader :output

  # The maximum width of a line, before it is separated in to a newline
  #
  # This defaults to 79, and should be a Fixnum
  attr_reader :maxwidth

  # The value that is appended to +output+ to add a new line.
  #
  # This defaults to "\n", and should be String
  attr_reader :newline

  # A lambda or Proc, that takes one argument, of a Fixnum, and returns
  # the corresponding number of spaces.
  #
  # By default this is:
  #   lambda {|n| ' ' * n}
  attr_reader :genspace

  # The number of spaces to be indented
  attr_reader :indent

  # The PrettyPrint::GroupQueue of groups in stack to be pretty printed
  attr_reader :group_queue

  # Returns the group most recently added to the stack.
  #
  # Contrived example:
  #   out = ""
  #   => ""
  #   q = PrettyPrint.new(out)
  #   => #<PrettyPrint:0x82f85c0 @output="", @maxwidth=79, @newline="\n", @genspace=#<Proc:0x82f8368@/home/vbatts/.rvm/rubies/ruby-head/lib/ruby/2.0.0/prettyprint.rb:82 (lambda)>, @output_width=0, @buffer_width=0, @buffer=[], @group_stack=[#<PrettyPrint::Group:0x82f8138 @depth=0, @breakables=[], @break=false>], @group_queue=#<PrettyPrint::GroupQueue:0x82fb7c0 @queue=[[#<PrettyPrint::Group:0x82f8138 @depth=0, @breakables=[], @break=false>]]>, @indent=0>
  #   q.group {
  #     q.text q.current_group.inspect
  #     q.text q.newline
  #     q.group(q.current_group.depth + 1) {
  #       q.text q.current_group.inspect
  #       q.text q.newline
  #       q.group(q.current_group.depth + 1) {
  #         q.text q.current_group.inspect
  #         q.text q.newline
  #         q.group(q.current_group.depth + 1) {
  #           q.text q.current_group.inspect
  #           q.text q.newline
  #         }
  #       }
  #     }
  #   }
  #   => 284
  #    puts out
  #   #<PrettyPrint::Group:0x8354758 @depth=1, @breakables=[], @break=false>
  #   #<PrettyPrint::Group:0x8354550 @depth=2, @breakables=[], @break=false>
  #   #<PrettyPrint::Group:0x83541cc @depth=3, @breakables=[], @break=false>
  #   #<PrettyPrint::Group:0x8347e54 @depth=4, @breakables=[], @break=false>
  def current_group
    @group_stack.last
  end

  # Breaks the buffer into lines that are shorter than #maxwidth
  def break_outmost_groups
    while @maxwidth < @output_width + @buffer_width
      return unless group = @group_queue.deq
      until group.breakables.empty?
        data = @buffer.shift
        @output_width = data.output(@output, @output_width)
        @buffer_width -= data.width
      end
      while !@buffer.empty? && Text === @buffer.first
        text = @buffer.shift
        @output_width = text.output(@output, @output_width)
        @buffer_width -= text.width
      end
    end
  end

  # This adds +obj+ as a text of +width+ columns in width.
  #
  # If +width+ is not specified, obj.length is used.
  #
  def text(obj, width=obj.length)
    if @buffer.empty?
      @output << obj
      @output_width += width
    else
      text = @buffer.last
      unless Text === text
        text = Text.new
        @buffer << text
      end
      text.add(obj, width)
      @buffer_width += width
      break_outmost_groups
    end
  end

  # This is similar to #breakable except
  # the decision to break or not is determined individually.
  #
  # Two #fill_breakable under a group may cause 4 results:
  # (break,break), (break,non-break), (non-break,break), (non-break,non-break).
  # This is different to #breakable because two #breakable under a group
  # may cause 2 results:
  # (break,break), (non-break,non-break).
  #
  # The text +sep+ is inserted if a line is not broken at this point.
  #
  # If +sep+ is not specified, " " is used.
  #
  # If +width+ is not specified, +sep.length+ is used. You will have to
  # specify this when +sep+ is a multibyte character, for example.
  #
  def fill_breakable(sep=' ', width=sep.length)
    group { breakable sep, width }
  end

  # This says "you can break a line here if necessary", and a +width+\-column
  # text +sep+ is inserted if a line is not broken at the point.
  #
  # If +sep+ is not specified, " " is used.
  #
  # If +width+ is not specified, +sep.length+ is used. You will have to
  # specify this when +sep+ is a multibyte character, for example.
  #
  def breakable(sep=' ', width=sep.length)
    group = @group_stack.last
    if group.break?
      flush
      @output << @newline
      @output << @genspace.call(@indent)
      @output_width = @indent
      @buffer_width = 0
    else
      @buffer << Breakable.new(sep, width, self)
      @buffer_width += width
      break_outmost_groups
    end
  end

  # Groups line break hints added in the block. The line break hints are all
  # to be used or not.
  #
  # If +indent+ is specified, the method call is regarded as nested by
  # nest(indent) { ... }.
  #
  # If +open_obj+ is specified, <tt>text open_obj, open_width</tt> is called
  # before grouping. If +close_obj+ is specified, <tt>text close_obj,
  # close_width</tt> is called after grouping.
  #
  def group(indent=0, open_obj='', close_obj='', open_width=open_obj.length, close_width=close_obj.length)
    text open_obj, open_width
    group_sub {
      nest(indent) {
        yield
      }
    }
    text close_obj, close_width
  end

  # Takes a block and queues a new group that is indented 1 level further.
  def group_sub
    group = Group.new(@group_stack.last.depth + 1)
    @group_stack.push group
    @group_queue.enq group
    begin
      yield
    ensure
      @group_stack.pop
      if group.breakables.empty?
        @group_queue.delete group
      end
    end
  end

  # Increases left margin after newline with +indent+ for line breaks added in
  # the block.
  #
  def nest(indent)
    @indent += indent
    begin
      yield
    ensure
      @indent -= indent
    end
  end

  # outputs buffered data.
  #
  def flush
    @buffer.each {|data|
      @output_width = data.output(@output, @output_width)
    }
    @buffer.clear
    @buffer_width = 0
  end

  # The Text class is the means by which to collect strings from objects.
  #
  # This class is intended for internal use of the PrettyPrint buffers.
  class Text # :nodoc:

    # Creates a new text object.
    #
    # This constructor takes no arguments.
    #
    # The workflow is to append a PrettyPrint::Text object to the buffer, and
    # being able to call the buffer.last() to reference it.
    #
    # As there are objects, use PrettyPrint::Text#add to include the objects
    # and the width to utilized by the String version of this object.
    def initialize
      @objs = []
      @width = 0
    end

    # The total width of the objects included in this Text object.
    attr_reader :width

    # Render the String text of the objects that have been added to this Text object.
    #
    # Output the text to +out+, and increment the width to +output_width+
    def output(out, output_width)
      @objs.each {|obj| out << obj}
      output_width + @width
    end

    # Include +obj+ in the objects to be pretty printed, and increment
    # this Text object's total width by +width+
    def add(obj, width)
      @objs << obj
      @width += width
    end
  end

  # The Breakable class is used for breaking up object information
  #
  # This class is intended for internal use of the PrettyPrint buffers.
  class Breakable # :nodoc:

    # Create a new Breakable object.
    #
    # Arguments:
    # * +sep+ String of the separator
    # * +width+ Fixnum width of the +sep+
    # * +q+ parent PrettyPrint object, to base from
    def initialize(sep, width, q)
      @obj = sep
      @width = width
      @pp = q
      @indent = q.indent
      @group = q.current_group
      @group.breakables.push self
    end

    # Holds the separator String
    #
    # The +sep+ argument from ::new
    attr_reader :obj

    # The width of +obj+ / +sep+
    attr_reader :width

    # The number of spaces to indent.
    #
    # This is inferred from +q+ within PrettyPrint, passed in ::new
    attr_reader :indent

    # Render the String text of the objects that have been added to this
    # Breakable object.
    #
    # Output the text to +out+, and increment the width to +output_width+
    def output(out, output_width)
      @group.breakables.shift
      if @group.break?
        out << @pp.newline
        out << @pp.genspace.call(@indent)
        @indent
      else
        @pp.group_queue.delete @group if @group.breakables.empty?
        out << @obj
        output_width + @width
      end
    end
  end

  # The Group class is used for making indentation easier.
  #
  # While this class does neither the breaking into newlines nor indentation,
  # it is used in a stack (as well as a queue) within PrettyPrint, to group
  # objects.
  #
  # For information on using groups, see PrettyPrint#group
  #
  # This class is intended for internal use of the PrettyPrint buffers.
  class Group # :nodoc:
    # Create a Group object
    #
    # Arguments:
    # * +depth+ - this group's relation to previous groups
    def initialize(depth)
      @depth = depth
      @breakables = []
      @break = false
    end

    # This group's relation to previous groups
    attr_reader :depth

    # Array to hold the Breakable objects for this Group
    attr_reader :breakables

    # Makes a break for this Group, and returns true
    def break
      @break = true
    end

    # Boolean of whether this Group has made a break
    def break?
      @break
    end

    # Boolean of whether this Group has been queried for being first
    #
    # This is used as a predicate, and ought to be called first.
    def first?
      if defined? @first
        false
      else
        @first = false
        true
      end
    end
  end

  # The GroupQueue class is used for managing the queue of Group to be pretty
  # printed.
  #
  # This queue groups the Group objects, based on their depth.
  #
  # This class is intended for internal use of the PrettyPrint buffers.
  class GroupQueue # :nodoc:
    # Create a GroupQueue object
    #
    # Arguments:
    # * +groups+ - one or more PrettyPrint::Group objects
    def initialize(*groups)
      @queue = []
      groups.each {|g| enq g}
    end

    # Enqueue +group+
    #
    # This does not strictly append the group to the end of the queue,
    # but instead adds it in line, base on the +group.depth+
    def enq(group)
      depth = group.depth
      @queue << [] until depth < @queue.length
      @queue[depth] << group
    end

    # Returns the outer group of the queue
    def deq
      @queue.each {|gs|
        (gs.length-1).downto(0) {|i|
          unless gs[i].breakables.empty?
            # group = gs.slice!(i, 1).first
            group = gs.slice(i, 1).first
            gs.delete_at(i)
            group.break
            return group
          end
        }
        gs.each {|group| group.break}
        gs.clear
      }
      return nil
    end

    # Remote +group+ from this queue
    def delete(group)
      @queue[group.depth].delete(group)
    end
  end

  # PrettyPrint::SingleLine is used by PrettyPrint.singleline_format
  #
  # It is passed to be similar to a PrettyPrint object itself, by responding to:
  # * #text
  # * #breakable
  # * #nest
  # * #group
  # * #flush
  # * #first?
  #
  # but instead, the output has no line breaks
  #
  class SingleLine
    # Create a PrettyPrint::SingleLine object
    #
    # Arguments:
    # * +output+ - String (or similar) to store rendered text. Needs to respond to '<<'
    # * +maxwidth+ - Argument position expected to be here for compatibility.
    #                This argument is a noop.
    # * +newline+ - Argument position expected to be here for compatibility.
    #               This argument is a noop.
    def initialize(output, maxwidth=nil, newline=nil)
      @output = output
      @first = [true]
    end

    # Add +obj+ to the text to be output.
    #
    # +width+ argument is here for compatibility. It is a noop argument.
    def text(obj, width=nil)
      @output << obj
    end

    # Appends +sep+ to the text to be output. By default +sep+ is ' '
    #
    # +width+ argument is here for compatibility. It is a noop argument.
    def breakable(sep=' ', width=nil)
      @output << sep
    end

    # Takes +indent+ arg, but does nothing with it.
    #
    # Yields to a block.
    def nest(indent) # :nodoc:
      yield
    end

    # Opens a block for grouping objects to be pretty printed.
    #
    # Arguments:
    # * +indent+ - noop argument. Present for compatibility.
    # * +open_obj+ - text appended before the &blok. Default is ''
    # * +close_obj+ - text appended after the &blok. Default is ''
    # * +open_width+ - noop argument. Present for compatibility.
    # * +close_width+ - noop argument. Present for compatibility.
    def group(indent=nil, open_obj='', close_obj='', open_width=nil, close_width=nil)
      @first.push true
      @output << open_obj
      yield
      @output << close_obj
      @first.pop
    end

    # Method present for compatibility, but is a noop
    def flush # :nodoc:
    end

    # This is used as a predicate, and ought to be called first.
    def first?
      result = @first[-1]
      @first[-1] = false
      result
    end
  end
end


## require 'prettyprint'

module Kernel
  # Returns a pretty printed object as a string.
  #
  # In order to use this method you must first require the PP module:
  #
  #   require 'pp'
  #
  # See the PP module for more information.
  def pretty_inspect
    PP.pp(self, '')
  end

  private
  # prints arguments in pretty form.
  #
  # pp returns argument(s).
  def pp(*objs) # :nodoc:
    objs.each {|obj|
      PP.pp(obj)
    }
    objs.size <= 1 ? objs.first : objs
  end
  module_function :pp # :nodoc:
end

### (From: https://github.com/ruby/ruby/blob/trunk/lib/pp.rb)

##
# A pretty-printer for Ruby objects.
#
# All examples assume you have loaded the PP class with:
#   require 'pp'
#
##
# == What PP Does
#
# Standard output by #p returns this:
#   #<PP:0x81fedf0 @genspace=#<Proc:0x81feda0>, @group_queue=#<PrettyPrint::GroupQueue:0x81fed3c @queue=[[#<PrettyPrint::Group:0x81fed78 @breakables=[], @depth=0, @break=false>], []]>, @buffer=[], @newline="\n", @group_stack=[#<PrettyPrint::Group:0x81fed78 @breakables=[], @depth=0, @break=false>], @buffer_width=0, @indent=0, @maxwidth=79, @output_width=2, @output=#<IO:0x8114ee4>>
#
# Pretty-printed output returns this:
#   #<PP:0x81fedf0
#    @buffer=[],
#    @buffer_width=0,
#    @genspace=#<Proc:0x81feda0>,
#    @group_queue=
#     #<PrettyPrint::GroupQueue:0x81fed3c
#      @queue=
#       [[#<PrettyPrint::Group:0x81fed78 @break=false, @breakables=[], @depth=0>],
#        []]>,
#    @group_stack=
#     [#<PrettyPrint::Group:0x81fed78 @break=false, @breakables=[], @depth=0>],
#    @indent=0,
#    @maxwidth=79,
#    @newline="\n",
#    @output=#<IO:0x8114ee4>,
#    @output_width=2>
#
##
# == Usage
#
#   pp(obj)             #=> obj
#   pp obj              #=> obj
#   pp(obj1, obj2, ...) #=> [obj1, obj2, ...]
#   pp()                #=> nil
#
# Output <tt>obj(s)</tt> to <tt>$></tt> in pretty printed format.
#
# It returns <tt>obj(s)</tt>.
#
##
# == Output Customization
#
# To define a customized pretty printing function for your classes,
# redefine method <code>#pretty_print(pp)</code> in the class.
#
# <code>#pretty_print</code> takes the +pp+ argument, which is an instance of the PP class.
# The method uses #text, #breakable, #nest, #group and #pp to print the
# object.
#
##
# == Pretty-Print JSON
#
# To pretty-print JSON refer to JSON#pretty_generate.
#
##
# == Author
# Tanaka Akira <akr@fsij.org>

class PP < PrettyPrint
  # Outputs +obj+ to +out+ in pretty printed format of
  # +width+ columns in width.
  #
  # If +out+ is omitted, <code>$></code> is assumed.
  # If +width+ is omitted, 79 is assumed.
  #
  # PP.pp returns +out+.
  def PP.pp(obj, out=$>, width=79)
    q = PP.new(out, width)
    q.guard_inspect_key {q.pp obj}
    q.flush
    #$pp = q
    out << "\n"
  end

  # Outputs +obj+ to +out+ like PP.pp but with no indent and
  # newline.
  #
  # PP.singleline_pp returns +out+.
  def PP.singleline_pp(obj, out=$>)
    q = SingleLine.new(out)
    q.guard_inspect_key {q.pp obj}
    q.flush
    out
  end

  # :stopdoc:
  ##def PP.mcall(obj, mod, meth, *args, &block)
  ##  mod.instance_method(meth).bind(obj).call(*args, &block)
  ##end
  # :startdoc:

  @sharing_detection = false
  class << self
    # Returns the sharing detection flag as a boolean value.
    # It is false by default.
    attr_accessor :sharing_detection
  end

  module PPMethods

    # Yields to a block
    # and preserves the previous set of objects being printed.
    def guard_inspect_key
      if Object.const_defined?(:Thread)
        if Thread.current[:__recursive_key__] == nil
          Thread.current[:__recursive_key__] = {}
        end

        if Thread.current[:__recursive_key__][:inspect] == nil
          Thread.current[:__recursive_key__][:inspect] = {}
        end

        save = Thread.current[:__recursive_key__][:inspect]

        begin
          Thread.current[:__recursive_key__][:inspect] = {}
          yield
        ensure
          Thread.current[:__recursive_key__][:inspect] = save
        end
      else
        if $__recursive_key__ == nil
          $__recursive_key__ = {}
        end

        if $__recursive_key__[:inspect] == nil
          $__recursive_key__[:inspect] = {}
        end

        save = $__recursive_key__[:inspect]

        begin
          $__recursive_key__[:inspect] = {}
          yield
        ensure
          $__recursive_key__[:inspect] = save
        end
      end
    end

    # Check whether the object_id +id+ is in the current buffer of objects
    # to be pretty printed. Used to break cycles in chains of objects to be
    # pretty printed.
    def check_inspect_key(id)
      if Object.const_defined?(:Thread)
        Thread.current[:__recursive_key__] &&
        Thread.current[:__recursive_key__][:inspect] &&
        Thread.current[:__recursive_key__][:inspect].include?(id)
      else
        $__recursive_key__ &&
        $__recursive_key__[:inspect] &&
        $__recursive_key__[:inspect].include?(id)
      end
    end

    # Adds the object_id +id+ to the set of objects being pretty printed, so
    # as to not repeat objects.
    def push_inspect_key(id)
      if Object.const_defined?(:Thread)
        Thread.current[:__recursive_key__][:inspect][id] = true
      else
        $__recursive_key__[:inspect][id] = true
      end
    end

    # Removes an object from the set of objects being pretty printed.
    def pop_inspect_key(id)
      if Object.const_defined?(:Thread)
        Thread.current[:__recursive_key__][:inspect].delete id
      else
        $__recursive_key__[:inspect].delete id
      end
    end

    # Adds +obj+ to the pretty printing buffer
    # using Object#pretty_print or Object#pretty_print_cycle.
    #
    # Object#pretty_print_cycle is used when +obj+ is already
    # printed, a.k.a the object reference chain has a cycle.
    def pp(obj)
      id = obj.object_id

      if check_inspect_key(id)
        group {obj.pretty_print_cycle self}
        return
      end

      begin
        push_inspect_key(id)
        group {obj.pretty_print self}
      ensure
        pop_inspect_key(id) unless PP.sharing_detection
      end
    end

    # A convenience method which is same as follows:
    #
    #   group(1, '#<' + obj.class.name, '>') { ... }
    def object_group(obj, &block) # :yield:
      group(1, '#<' + obj.class.name, '>', &block)
    end

    # A convenience method, like object_group, but also reformats the Object's
    # object_id.
    def object_address_group(obj, &block)
      ##str = Kernel.instance_method(:to_s).bind(obj).call
      str = PP.any_to_s(obj)
      str.chomp!('>')
      group(1, str, '>', &block)
    end

    # A convenience method which is same as follows:
    #
    #   text ','
    #   breakable
    def comma_breakable
      text ','
      breakable
    end

    # Adds a separated list.
    # The list is separated by comma with breakable space, by default.
    #
    # #seplist iterates the +list+ using +iter_method+.
    # It yields each object to the block given for #seplist.
    # The procedure +separator_proc+ is called between each yields.
    #
    # If the iteration is zero times, +separator_proc+ is not called at all.
    #
    # If +separator_proc+ is nil or not given,
    # +lambda { comma_breakable }+ is used.
    # If +iter_method+ is not given, :each is used.
    #
    # For example, following 3 code fragments has similar effect.
    #
    #   q.seplist([1,2,3]) {|v| xxx v }
    #
    #   q.seplist([1,2,3], lambda { q.comma_breakable }, :each) {|v| xxx v }
    #
    #   xxx 1
    #   q.comma_breakable
    #   xxx 2
    #   q.comma_breakable
    #   xxx 3
    def seplist(list, sep=nil, iter_method=:each) # :yield: element
      sep ||= lambda { comma_breakable }
      first = true
      list.__send__(iter_method) {|*v|
        if first
          first = false
        else
          sep.call
        end
        yield(*v)
      }
    end

    # A present standard failsafe for pretty printing any given Object
    def pp_object(obj)
      object_address_group(obj) {
        seplist(obj.pretty_print_instance_variables, lambda { text ',' }) {|v|
          breakable
          v = v.to_s if Symbol === v
          text v
          text '='
          group(1) {
            breakable ''
            pp(obj.instance_eval(v))
          }
        }
      }
    end

    # A pretty print for a Hash
    def pp_hash(obj)
      group(1, '{', '}') {
        seplist(obj, nil, :each_pair) {|k, v|
          group {
            pp k
            text '=>'
            group(1) {
              breakable ''
              pp v
            }
          }
        }
      }
    end
  end

  include PPMethods

  class SingleLine < PrettyPrint::SingleLine # :nodoc:
    include PPMethods
  end

  module ObjectMixin # :nodoc:
    # 1. specific pretty_print
    # 2. specific inspect
    # 3. generic pretty_print

    # A default pretty printing method for general objects.
    # It calls #pretty_print_instance_variables to list instance variables.
    #
    # If +self+ has a customized (redefined) #inspect method,
    # the result of self.inspect is used but it obviously has no
    # line break hints.
    #
    # This module provides predefined #pretty_print methods for some of
    # the most commonly used built-in classes for convenience.
    def pretty_print(q)
      ##method_method = Object.instance_method(:method).bind(self)
      begin
      ##  inspect_method = method_method.call(:inspect)
        inspect_method = PP.mcall_object_inspect(self)
      rescue NameError
      end
      if inspect_method && /\(Kernel\)#/ !~ inspect_method.inspect
        q.text self.inspect
      elsif !inspect_method && self.respond_to?(:inspect)
        q.text self.inspect
      else
        q.pp_object(self)
      end
    end

    # A default pretty printing method for general objects that are
    # detected as part of a cycle.
    def pretty_print_cycle(q)
      q.object_address_group(self) {
        q.breakable
        q.text '...'
      }
    end

    # Returns a sorted array of instance variable names.
    #
    # This method should return an array of names of instance variables as symbols or strings as:
    # +[:@a, :@b]+.
    def pretty_print_instance_variables
      instance_variables.sort
    end

    #
    # **Notice: #pretty_print_inspect is not supported yet.**
    #
    # Is #inspect implementation using #pretty_print.
    # If you implement #pretty_print, it can be used as follows.
    #
    #   alias inspect pretty_print_inspect
    #
    # However, doing this requires that every class that #inspect is called on
    # implement #pretty_print, or a RuntimeError will be raised.
    ##def pretty_print_inspect
    ##  if /\(PP::ObjectMixin\)#/ =~ Object.instance_method(:method).bind(self).call(:pretty_print).inspect
    ##    raise "pretty_print is not overridden for #{self.class}"
    ##  end
    ##  PP.singleline_pp(self, '')
    ##end
  end
end

class Array # :nodoc:
  def pretty_print(q) # :nodoc:
    q.group(1, '[', ']') {
      q.seplist(self) {|v|
        q.pp v
      }
    }
  end

  def pretty_print_cycle(q) # :nodoc:
    q.text(empty? ? '[]' : '[...]')
  end
end

class Hash # :nodoc:
  def pretty_print(q) # :nodoc:
    q.pp_hash self
  end

  def pretty_print_cycle(q) # :nodoc:
    q.text(empty? ? '{}' : '{...}')
  end
end

class << ENV # :nodoc:
  def pretty_print(q) # :nodoc:
    h = {}
    ENV.keys.sort.each {|k|
      h[k] = ENV[k]
    }
    q.pp_hash h
  end
end

class Struct # :nodoc:
  def pretty_print(q) # :nodoc:
    q.group(1, sprintf("#<struct %s", PP.mcall_kernel_class(self).to_s), '>') {
      q.seplist(PP.mcall_struct_members(self), lambda { q.text "," }) {|member|
        q.breakable
        q.text member.to_s
        q.text '='
        q.group(1) {
          q.breakable ''
          q.pp self[member]
        }
      }
    }
  end

  def pretty_print_cycle(q) # :nodoc:
    q.text sprintf("#<struct %s:...>", PP.mcall_kernel_class(self).to_s)
  end
end

class Range # :nodoc:
  def pretty_print(q) # :nodoc:
    q.pp self.begin
    q.breakable ''
    q.text(self.exclude_end? ? '...' : '..')
    q.breakable ''
    q.pp self.end
  end
end

class File < IO # :nodoc:
  class Stat # :nodoc:
    def pretty_print(q) # :nodoc:
      require 'etc.so'
      q.object_group(self) {
        q.breakable
        q.text sprintf("dev=0x%x", self.dev); q.comma_breakable
        q.text "ino="; q.pp self.ino; q.comma_breakable
        q.group {
          m = self.mode
          q.text sprintf("mode=0%o", m)
          q.breakable
          q.text sprintf("(%s %c%c%c%c%c%c%c%c%c)",
            self.ftype,
            (m & 0400 == 0 ? ?- : ?r),
            (m & 0200 == 0 ? ?- : ?w),
            (m & 0100 == 0 ? (m & 04000 == 0 ? ?- : ?S) :
                             (m & 04000 == 0 ? ?x : ?s)),
            (m & 0040 == 0 ? ?- : ?r),
            (m & 0020 == 0 ? ?- : ?w),
            (m & 0010 == 0 ? (m & 02000 == 0 ? ?- : ?S) :
                             (m & 02000 == 0 ? ?x : ?s)),
            (m & 0004 == 0 ? ?- : ?r),
            (m & 0002 == 0 ? ?- : ?w),
            (m & 0001 == 0 ? (m & 01000 == 0 ? ?- : ?T) :
                             (m & 01000 == 0 ? ?x : ?t)))
        }
        q.comma_breakable
        q.text "nlink="; q.pp self.nlink; q.comma_breakable
        q.group {
          q.text "uid="; q.pp self.uid
          begin
            pw = Etc.getpwuid(self.uid)
          rescue ArgumentError
          end
          if pw
            q.breakable; q.text "(#{pw.name})"
          end
        }
        q.comma_breakable
        q.group {
          q.text "gid="; q.pp self.gid
          begin
            gr = Etc.getgrgid(self.gid)
          rescue ArgumentError
          end
          if gr
            q.breakable; q.text "(#{gr.name})"
          end
        }
        q.comma_breakable
        q.group {
          q.text sprintf("rdev=0x%x", self.rdev)
          if self.rdev_major && self.rdev_minor
            q.breakable
            q.text sprintf('(%d, %d)', self.rdev_major, self.rdev_minor)
          end
        }
        q.comma_breakable
        q.text "size="; q.pp self.size; q.comma_breakable
        q.text "blksize="; q.pp self.blksize; q.comma_breakable
        q.text "blocks="; q.pp self.blocks; q.comma_breakable
        q.group {
          t = self.atime
          q.text "atime="; q.pp t
          q.breakable; q.text "(#{t.tv_sec})"
        }
        q.comma_breakable
        q.group {
          t = self.mtime
          q.text "mtime="; q.pp t
          q.breakable; q.text "(#{t.tv_sec})"
        }
        q.comma_breakable
        q.group {
          t = self.ctime
          q.text "ctime="; q.pp t
          q.breakable; q.text "(#{t.tv_sec})"
        }
      }
    end
  end
end

class MatchData # :nodoc:
  def pretty_print(q) # :nodoc:
    nc = []
    self.regexp.named_captures.each {|name, indexes|
      indexes.each {|i| nc[i] = name }
    }
    q.object_group(self) {
      q.breakable
      q.seplist(0...self.size, lambda { q.breakable }) {|i|
        if i == 0
          q.pp self[i]
        else
          if nc[i]
            q.text nc[i]
          else
            q.pp i
          end
          q.text ':'
          q.pp self[i]
        end
      }
    }
  end
end

class Object < BasicObject # :nodoc:
  include PP::ObjectMixin
end

[Numeric, Symbol, FalseClass, TrueClass, NilClass, Module, Proc].each {|c|
  c.class_eval {
    def pretty_print_cycle(q)
      q.text inspect
    end
  }
}

[Numeric, FalseClass, TrueClass, Module, Proc].each {|c|
  c.class_eval {
    def pretty_print(q)
      q.text inspect
    end
  }
}
