assert('PPTest test_list0123_12') do
  assert_equal("[0, 1, 2, 3]\n", PP.pp([0,1,2,3], '', 12))
end

assert('PPTest test_list0123_11') do
  assert_equal("[0,\n 1,\n 2,\n 3]\n", PP.pp([0,1,2,3], '', 11))
end

assert('PPTest test_struct_override_members') do # [ruby-core:7865]
  OverriddenStruct = Struct.new("OverriddenStruct", :members, :class)
  a = OverriddenStruct.new(1,2)
  result = PP.pp(a, '')
  assert_equal("#<struct Struct::OverriddenStruct members=1, class=2>\n", result)
end

assert('PPTest test_redefined_method') do
  o = ""
  def o.method
  end
  assert_equal(%(""\n), PP.pp(o, ""))
end

assert('PPInspectTest test_proc') do
  a = proc {1}
  assert_equal("#{a.inspect}\n", PP.pp(a, ''))
end

assert('PPInspectTest test_to_s_with_iv') do
  a = Object.new
  def a.to_s() "aaa" end
  a.instance_eval { @a = nil }
  result = PP.pp(a, '')
  assert_equal("#{a.inspect}\n", result)
end

assert('PPInspectTest test_to_s_without_iv') do
  a = Object.new
  def a.to_s()
    "aaa"
  end
  result = PP.pp(a, '')
  assert_equal("#{a.inspect}\n", result)
end

assert('PPCycleTest test_array') do
  a = []
  a << a
  assert_equal("[[...]]\n", PP.pp(a, ''))
  ## Array#inspect in mruby is diffrent from one in CRuby
  # assert_equal("#{a.inspect}\n", PP.pp(a, ''))
end

assert('PPCycleTest test_hash') do
  a = {}
  a[0] = a
  assert_equal("{0=>{...}}\n", PP.pp(a, ''))
  # assert_equal("#{a.inspect}\n", PP.pp(a, ''))
end


assert('PPCycleTest test_struct') do
  S = Struct.new("S", :a, :b)
  a = S.new(1,2)
  a.b = a
  assert_equal("#<struct Struct::S a=1, b=#<struct Struct::S:...>>\n", PP.pp(a, ''))
  # assert_equal("#{a.inspect}\n", PP.pp(a, ''))
end

assert('PPCycleTest test_object') do
  a = Object.new
  a.instance_eval {@a = a}
  assert_equal(a.inspect + "\n", PP.pp(a, ''))
end

assert('PPCycleTest test_anonyomus') do
  a = Class.new.new
  assert_equal(a.inspect + "\n", PP.pp(a, ''))
end

assert('PPCycleTest test_share_nil') do
  begin
    PP.sharing_detection = true
    a = [nil, nil]
    assert_equal("[nil, nil]\n", PP.pp(a, ''))
  ensure
    PP.sharing_detection = false
  end
end

assert('PPSingleLineTest test_hash') do
  assert_equal("{1=>1}", PP.singleline_pp({ 1 => 1}, '')) # [ruby-core:02699]
  assert_equal("[1#{', 1'*99}]", PP.singleline_pp([1]*100, ''))
end
