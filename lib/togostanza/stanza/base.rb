require 'active_support/core_ext/module/delegation'
require 'flavour_saver'
require 'hashie/mash'

FS.register_helper :adjust_iframe_height_script do
  <<-HTML.strip_heredoc.html_safe
    <script>$(function() {
      height = this.body.offsetHeight + 43;
      parent.postMessage(JSON.stringify({height: height, id: name}), "*");
    });</script>
  HTML
end

FS.register_helper :download_csv do
  <<-HTML.strip_heredoc.html_safe
    <script>$(function() {
      #{init_download_script}
      $("div#stanza_buttons").append("<a id='download_csv' download='stanza.csv' href='#'><i class='fa fa-file-o'></i> CSV</a>");

      var csv = '';
      var tables = $('body > table');
      if (tables.length > 0) {
        for (var tableNum = 0; tableNum < tables.length; tableNum++) {
          var table = tables[tableNum];
          var rowLength = table.rows.length;
          var colLength = table.rows[0].cells.length;
          for (var i = 0; i < rowLength; i++) {
            for (var j = 0; j < colLength; j++) {
              var cell        = table.rows[i].cells[j];
              var textContent = null;

              if ($(cell).find("li")[0]) {
                textContent = $(cell).find('li').map(function(){
                  return this.textContent.replace(/^\\s+/mg, "").replace(/\\n/g, "");
                }).get().join(" | ");
              } else if ($(cell).find("table")[0]) {
                textContent = $(cell).find('table').find('th, td').map(function(){
                  return this.textContent.replace(/^\\s+/mg, "").replace(/\\n/g, "");
                }).get().join(" | ");
              } else {
                textContent = cell.textContent.replace(/^\\s+/mg, "").replace(/\\n/g, "");
              }
              if (j === colLength - 1) {
                csv +=  textContent;
              } else {
                csv +=  textContent + ', ';
              }
            }
            csv += "\\r\\n";
          }
        }
      }

      document.querySelector('#download_csv').addEventListener('click', (e) => {
        e.target.href = 'data:text/plain;charset=UTF-8' + (window.btoa ? ';base64,' + btoa(csv) : ',' + csv);
      });
    });
    </script>
  HTML
end

FS.register_helper :download_json do
  json = except(:css_uri).to_json

  <<-HTML.strip_heredoc.html_safe
    <script>$(function() {
      #{init_download_script}
      $("div#stanza_buttons").append("<a id='download_json' download='stanza.json' href='#'><i class='fa fa-file-o'></i> JSON</a>");
      var json_str = JSON.stringify(#{json}, null, '\t');

      document.querySelector('#download_json').addEventListener('click', (e) => {
        e.target.href = 'data:application/json;charset=UTF-8' + (window.btoa ? ';base64,' + btoa(json_str) : ',' + json_str);
      });
    });
    </script>
  HTML
end

FS.register_helper :download_svg do
  <<-HTML.strip_heredoc.html_safe
    <script>$(function() {
      #{init_download_script}
      $("div#stanza_buttons").append("<a id='download_svg' download='stanza.svg' href='#'><i class='fa fa-file-o'></i> SVG</a>");

      document.querySelector('#download_svg').addEventListener('click', (e) => {
        var svg = $("svg");
        if (svg[0]) {
          if (!svg.attr("xmlns")) {
            svg.attr("xmlns","http://www.w3.org/2000/svg");
          }
          if (!svg.attr("xmlns:xlink")) {
            svg.attr("xmlns:xlink","http://www.w3.org/1999/xlink");
          }

          var svgText = svg.wrap('<div>').parent().html();
          e.target.href = 'data:image/svg+xml' + (window.btoa ? ';base64,' + btoa(svgText) : ',' + svgText);
        } else {
          // TODO...
          console.log("Can't open svg file");
        }
      });
    });
    </script>
  HTML
end

FS.register_helper :download_image do
  <<-HTML.strip_heredoc.html_safe
    <script type="application/javascript" src="/stanza/assets/canvas-toBlob.js"></script>

    <script type="application/javascript" src="http://canvg.googlecode.com/svn/trunk/rgbcolor.js"></script>
    <script type="application/javascript" src="http://canvg.googlecode.com/svn/trunk/StackBlur.js"></script>
    <script type="application/javascript" src="http://canvg.googlecode.com/svn/trunk/canvg.js"></script>

    <script>$(function() {
      #{init_download_script}
      $("div#stanza_buttons").append("<a id='download_image' download='stanza.png' href='#'><i class='fa fa-file-o'></i> IMAGE</a>");

      $("body").append("<div style='display: none;'><canvas id='drawarea'></canvas></div>");

      document.querySelector('#download_image').addEventListener('click', (e) => {
        var svg = $("svg");
        if (svg[0]) {
          var svgText = svg.wrap('<div>').parent().html();
          canvg('drawarea', svgText, { 
            renderCallback: function() {
              var canvas = $("#drawarea")[0];

              canvas.toBlob(function(blob) {
                var blob_url = window.URL.createObjectURL(blob);
                e.target.href = blob_url;
              }, "image/png");
            }
          });
        } else {
          // TODO...
          console.log("Can't open image file");
        }
      });
    });
    </script>
  HTML
end

def init_download_script
  <<-HTML.strip_heredoc.html_safe
    if (!$("div#stanza_buttons")[0]) {
      $('body').append("<div id='tool_bar'><div id='stanza_buttons' class='pull-left'></div></div>");
    }
  HTML
end

module TogoStanza::Stanza
  autoload :ExpressionMap, 'togostanza/stanza/expression_map'
  autoload :Grouping,      'togostanza/stanza/grouping'
  autoload :Querying,      'togostanza/stanza/querying'

  class Context < Hashie::Mash
    disable_warnings
    def respond_to_missing?(*)
      # XXX It looks ugly, but we need use not pre-defined properties
      true
    end
  end

  class Base
    extend ExpressionMap::Macro
    include Querying
    include Grouping

    define_expression_map :properties
    define_expression_map :resources

    property :css_uri do |css_uri|
      if css_uri
        css_uri.split(',')
      else
        %w(
          //cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/2.2.2/css/bootstrap.min.css
          //cdnjs.cloudflare.com/ajax/libs/font-awesome/4.2.0/css/font-awesome.min.css
          /stanza/assets/stanza.css
        )
      end
    end

    class_attribute :root

    def self.id
      to_s.underscore.sub(/_stanza$/, '')
    end

    delegate :id, to: 'self.class'

    def initialize(params = {})
      @params = params
    end

    attr_reader :params

    def context
      Context.new(properties.resolve_all_in_parallel(self, params))
    end

    def resource(name)
      resources.resolve(self, name, params)
    end

    def render
      path = File.join(root, 'template.hbs')

      Tilt.new(path).render(context)
    end

    def metadata(server_url)
      path = File.join(root, 'metadata.json')

      if File.exist?(path)
        orig = JSON.load(open(path))
        stanza_uri = "#{server_url}/#{orig['id']}"

        usage_attrs = orig['parameter'].map {|hash|
          unless hash['key'].start_with?("data-stanza-") then
            hash['key'] = "data-stanza-" <<  hash['key']
          end
          "#{hash['key']}=\"#{hash['example']}\""
        }.push("data-stanza=\"#{stanza_uri}\"").join(' ')

        append_prefix_to_hash_keys(orig.merge(usage: "<div #{usage_attrs}></div>"), 'stanza').merge('@id' => stanza_uri)
      else
        nil
      end
    end

    private

    def append_prefix_to_hash_keys(hash, prefix)
      hash.each_with_object({}) do |(key, value), new_hash|
        new_hash["#{prefix}:#{key}"] = expand_values(value, prefix)
      end
    end

    def expand_values(value, prefix)
      case value
      when Hash
        append_prefix_to_hash_keys(value, prefix)
      when Array
        value.map {|v| expand_values(v, prefix) }
      else
        value
      end
    end
  end
end
