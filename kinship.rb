#!/usr/bin/env ruby
require "erb"
require "optparse"
require "yaml"

class String
  def sanitize; self.gsub('::', ''); end
end

class Graph
  attr_accessor :font_name, :font_size, :klasses, :show_methods
  def initialize(&block)
    @klasses = []
    yield self if block_given?
  end

  def render
    TEMPLATE.call(self)
  end

  %w(uses has_many has_one).each do |type|
    define_method("#{type}_relationships") do
      klasses.flat_map do |klass|
        klass.send(type).map do |dependency|
          [dependency.sanitize, klass.sanitized_name]
        end
      end
    end
  end
end

class Model
  attr_accessor :name, :methods, :uses, :has_many, :has_one
  def initialize(attributes={})
    @methods = []
    @uses = []
    @has_many = []
    @has_one = []
    attributes.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
  end

  def sanitized_name
    name.sanitize
  end
end

### MAIN
options = {}
OptionParser.new do |opts|
  opts.banner = <<-DESC
  Usage:
    kinship.rb [options]

  Examples:
    TODO
DESC

  opts.separator ""
  opts.separator "OPTIONS:"

  opts.on("-i", "--input-file FILENAME", "Required. The name of the file containing object and relationship information. Must be in YAML format.") do |file|
    options[:input_file] = file
  end

  opts.on("-h", "--help", "Displays this help message.") do
    puts opts
    exit
  end
end.parse!

raise OptionParser::MissingArgument.new("Input file is required. Run `kinship.rb` -h for help.") unless options[:input_file]
raise OptionParser::InvalidArgument.new("Cannot find file '#{options[:input_file]}'") unless File.exist?(options[:input_file])

TEMPLATE = lambda { |graph| ERB.new(DATA.read, nil, '-').result }

objects = YAML.load_file(options[:input_file])
graph = Graph.new do |g|
  g.font_name = "Bitstream Vera Sans"
  g.font_size = 12
  g.show_methods = true
  g.klasses = objects.map { |attributes| Model.new(attributes) }
end

puts graph.render

__END__
digraph G {
    fontname = "<%= graph.font_name %>"
    fontsize = <%= graph.font_size %>

    node [
        fontname = "<%= graph.font_name %>"
        fontsize = <%= graph.font_size %>
        shape = "record"
    ]

    edge [
        fontname = "<%= graph.font_name %>"
        fontsize = <%= graph.font_size %>
    ]
    <%- graph.klasses.each do |klass| %>
    <%= klass.sanitized_name %> [
      <% if graph.show_methods %>
      <% methods = klass.methods.map { |m| "+ #{m}()\\l" }.join('') %>
      label = "{<%= klass.name %>|<%= methods %>}"
      <% else %>
      label = "{<%= klass.name %>}"
      <% end %>
    ]
    <%- end %>
    edge [
        arrowhead = "open"
        style = "dashed"
        label = "«use»"
    ]
    <%- graph.uses_relationships.each do |(supplier, client)| %>
    <%= client %> -> <%= supplier %>
    <%- end %>

    edge [
        arrowhead = "odiamond"
        style = "solid"
        label = ""
        labeldistance = 3
        headlabel = "0..*"
    ]
    <%- graph.has_many_relationships.each do |(belongs_to, has_many)| %>
    <%= has_many %> -> <%= belongs_to %>
    <%- end %>

    edge [
        arrowhead = "odiamond"
        style = "solid"
        label = ""
        labeldistance = 3
        headlabel = "0..1"
    ]
    <%- graph.has_one_relationships.each do |(belongs_to, has_one)| %>
    <%= has_one %> -> <%= belongs_to %>
    <%- end %>
}
