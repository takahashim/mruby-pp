MRuby::Gem::Specification.new('mruby-pp') do |spec|
  spec.license = 'MIT'
  spec.author  = 'Masayoshi Takahashi'
  spec.summary = 'PrettyPrint library ported from CRuby'

  # Add compile flags
  # spec.cc.flags << ''

  # Add cflags to all
  # spec.mruby.cc.flags << '-g'

  # Add libraries
  # spec.linker.libraries << 'external_lib'

  spec.add_dependency('mruby-sprintf')
  spec.add_dependency('mruby-string-ext')
  spec.add_dependency('mruby-hash-ext')
  spec.add_dependency('mruby-proc-ext')
  spec.add_dependency('mruby-struct')
  spec.add_dependency('mruby-io', :github => 'iij/mruby-io')
  spec.add_dependency('mruby-env', :github => 'iij/mruby-env')
  spec.add_dependency('mruby-regexp-pcre', :github => 'iij/mruby-regexp-pcre')

  # Default build files
  spec.rbfiles = ["#{dir}/mrblib/pp.rb"]
  # spec.objs = Dir.glob("#{dir}/src/*.{c,cpp,m,asm,S}").map { |f| objfile(f.relative_path_from(dir).pathmap("#{build_dir}/%X")) }
  # spec.test_rbfiles = Dir.glob("#{dir}/test/*.rb")
  # spec.test_objs = Dir.glob("#{dir}/test/*.{c,cpp,m,asm,S}").map { |f| objfile(f.relative_path_from(dir).pathmap("#{build_dir}/%X")) }
  # spec.test_preload = 'test/assert.rb'

  # Values accessible as TEST_ARGS inside test scripts
  # spec.test_args = {'tmp_dir' => Dir::tmpdir}
end
