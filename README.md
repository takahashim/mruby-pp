# mruby-pp

Pretty-Print library ported from CRuby.

* https://github.com/ruby/ruby/blob/trunk/lib/pp.rb
* https://github.com/ruby/ruby/blob/trunk/lib/prettyprint.rb

## Install

add conf.gem to `build_config.rb`:

    MRuby::Build.new do |conf|
    
      # ... (snip) ...
    
      conf.gem :github => 'takahashim/mruby-pp'
    end

## Using mrbgems

This library depends on these mrbgems:

* mruby-sprintf
* mruby-string-ext
* mruby-hash-ext
* mruby-proc-ext
* mruby-struct
* mruby-io (github: 'iij/mruby-io')
* mruby-env (github: 'iij/mruby-env')
* mruby-regexp-pcre (github: 'iij/mruby-regexp-pcre')

## Limitation

* This libarary does not support `pretty_print_inspect` yet. You cannot use pp as `Object#inspect`.

## License

Same as CRuby's (Ruby's or 2-clause BSDL).
See file COPYING or BSDL.

## Author

Original library in Cruby is written by Tanaka Akira.
mruby version of this library is ported by Masayoshi Takahashi.






