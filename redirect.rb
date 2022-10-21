Dir['./_posts/**/*.md'].each do |filename|
  puts filename
  lines = File.readlines(filename)

  first = lines.shift
  lines.unshift "  - https://blog.widefix.com/#{filename.sub(/\.\/_posts\/\d+-\d+-\d+-/, '').sub(/\.md/, '')}\n"
  lines.unshift "redirect_to:\n"
  lines.unshift(first)

  File.open(filename, 'w') do |f|
    lines.each { |l| f << l }
  end
end
