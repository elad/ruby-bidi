# Ruby BiDi

Ruby gem to help working with bidirectional (left-to-right and right-to-left) text.

### Install

```shell
gem install bidi
```

### Use

Require the `bidi` module and use `to_visual`:

```ruby
require "bidi"

bidi = Bidi.new
bidi_string = bidi.to_visual "My סטרינג"
```

When rendering right-to-left text, some writers require reversing the string before passing it to them. [Prawn](https://github.com/prawnpdf/prawn) is one such example. The `to_rendered` function does this for you:

```ruby
require "prawn"
require "bidi"

Prawn::Document.generate("hello.pdf") do
  self.text_direction = :rtl

  bidi = Bidi.new
  text bidi.to_rendered "My סטרינג"
end

```

### License

Copyright (c) 2014 Amit Yaron <<amit@phpandmore.net>>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
