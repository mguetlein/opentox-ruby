
OT_LOGO = "http://opentox.informatik.uni-freiburg.de/ot-logo.png"


class String
  def link_urls
    self.gsub(/(?i)http:\/\/[^\r\n\s']*/, '<a href=\0>\0</a>')
  end
end

module OpenTox
  
  def self.text_to_html( text, related_links=nil, description=nil, post_params=nil )
    
    html = <<EOF
<html>
<img src="
EOF
    html.chomp!
    html += OT_LOGO
    html += <<EOF 
">
<body>
EOF
   html.chomp!
   html += "<h3>Description</h3><pre><p>"+description.link_urls+"</p></pre>" if description
   html += "<h3>Related links</h3><pre><p>"+related_links.link_urls+"</p></pre>" if related_links
   if post_params
      html += "<h3>POST parameters</h3>"
      post_params.each do |p|
        html += "<pre><p><table><thead><tr><th>param</th><th>default_value</th></tr></thead>"
        p.each do |k,v|
          html += "<tr><th>"+k.to_s+"</th><th>"+(v!=nil ? v.to_s : "<i>mandatory</i>")+"</th></tr>"
        end
        html += "</table></p></pre>"
      end
   end
   html += "<h3>Content</h3>" if description || related_links
   html += <<EOF
<pre>
<p style="padding:15px; border:10px solid #5D308A">
EOF
   html.chomp!
   html += text.link_urls
   html += <<EOF
</p>
</pre>
</body>
<html>
EOF
    html
  end
  
end

#puts OpenTox.text_to_html("bla")