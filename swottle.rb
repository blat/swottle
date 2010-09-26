%w(rubygems sinatra haml sass dm-core dm-validations dm-timestamps dm-aggregates builder).each { |dependency| require dependency }

# Include configuration file
require 'config'

class Swottle
  include DataMapper::Resource

  property :id, Integer, :serial => true
  property :message, DataMapper::Types::Text, :nullable => false
  property :email, String, :nullable => true, :format => :email_address
  property :created_at, DateTime
  property :updated_at, DateTime
  property :deleted_at, ParanoidDateTime
  property :deleted, ParanoidBoolean

  def self.latest(count = 20)
    return Swottle.all(:limit => count, :order => [:created_at.desc])
  end

  def self.random
    if Swottle.count > 0 then
      return Swottle.get(1 + rand(Swottle.count))
    end
  end

  def comments
    return Comment.all(:swottle => self.id, :order => [:created_at.desc])
  end

  def notity
    if not self.email.nil? then
      # TODO : send email to author
    end
  end

end

class Comment
  include DataMapper::Resource

  property :id, Integer, :serial => true
  property :message, DataMapper::Types::Text, :nullable => false
  property :author, String, :nullable => false
  property :created_at, DateTime
  property :updated_at, DateTime
  property :deleted_at, ParanoidDateTime
  property :deleted, ParanoidBoolean
  property :swottle, Integer, :nullable => false

end

DataMapper.auto_upgrade!


get '/' do
  haml :index
end

post '/create' do
  @swottle = Swottle.new
  if params[:email] != '' then
    @swottle.email = params[:email]
  end
  @swottle.message = params[:message]
  if @swottle.save then
    redirect "#{Url}/get/#{@swottle.id}"
  end
  haml :index
end

post '/comment/:id' do
  @swottle = Swottle.get(params[:id])
  @comment = Comment.new
  if params[:author] != '' then
    @comment.author = params[:author]
  end
  @comment.message = params[:message]
  @comment.swottle = @swottle.id
  if @comment.save then
    @swottle.notify
    redirect "#{Url}/get/#{@swottle.id}"
  end
  haml :get
end

get '/get/:id' do
  @swottle = Swottle.get(params[:id])
  @comment = nil
  haml :get
end

get '/random' do
  @swottle = Swottle.random
  haml :get
end

get '/dev' do
  haml :dev
end

get '/about' do
  haml :about
end

get '/random/:format' do
  @swottle = Swottle.random
  format = params[:format]
  if format == "xml" then
    content_type "application/xml", :charset => "utf-8"
    builder :layout => false do |format|
      format.instruct! :xml, :version => '1.0'
      format.swottle do
        format.link "#{Url}/get/#{@swottle.id}"
        format.message @swottle.message
        format.date Time.parse(@swottle.created_at.to_s).rfc822()
        format.comments do
          @swottle.comments.each do |comment|
            format.comment do
              format.message comment.message
              format.author comment.author
              format.date Time.parse(comment.created_at.to_s).rfc822()
            end
          end
        end
      end
    end
  else
    raise "Unknown format \"#{format}\""
  end
end

get '/swottle.css' do
  headers "Content-Type" => "text/css; charset=utf-8"
  sass :stylesheet
end

get '/rss.xml' do
  content_type "application/xml", :charset => "utf-8"
  builder :layout => false do |xml|
    xml.instruct! :xml, :version => "1.0"
    xml.rss :version => "2.0" do
      xml.channel do
        xml.title Title
        xml.description SubTitle
        xml.link Url
        Swottle.latest.each do |swottle|
          xml.item do
            xml.title swottle.email
            xml.link "#{Url}/get/#{swottle.id}"
            xml.description swottle.message
            xml.pubDate Time.parse(swottle.created_at.to_s).rfc822()
            xml.guid swottle.id
          end
        end
      end
    end
  end
end


use_in_file_templates!

__END__

@@ layout
!!! strict
%html
  %head
    %title= Title + " | " + SubTitle
    %link{:rel => "stylesheet", :href => "#{Url}/swottle.css", :type => "text/css"}
    %link{:rel => "alternate", :href => "#{Url}/rss.xml", :type => "application/rss+xm"}
  %body
    #head
      %h1
        %a{:href => Url, :title => Title}= Title
      %ul.topbar
        %li
          %a{:href => "#{Url}/random"} Randomize
        %li
          %a{:href => "#{Url}/dev"} Developers
        %li
          %a{:href => "#{Url}/about"} About
    #main
      %div.sidebar.box
        %p.introduction Swottle is sea web bottle...
      %div.sidebar.box
        %h3 Developers
        %p 
          You can include a random swottle to your website. For that, using our
          %a{:href => "#{Url}/dev"} API.
      = yield
    #foot
      Powered by
      %a{:href => "http://www.sinatrarb.com"} Sinatra
      \-
      %a{:href => Url}= Title
      is a
      %a{:href => "http://www.blizzart.net"} Blizz'art
      and
      %a{:href => "http://www.flexiden.org"} Flexiden
      production

@@ index
%div.new.box
  %h3 Send a swottle
  %form{:action => "#{Url}/create", :method => "post"}
    - if not @swottle.nil? then
      - message = @swottle.message
      - email = @swottle.email
    %label{:for => "message"} Your message:
    %textarea#message{:name => "message"}= message
    %label{:for => "email"} Your email:
    %input#email{:type => "text", :name => "email", :value => email}
    %span.description Optional, only if you want be notify when a comment is submit
    %input{:type => "submit", :value => "Send"}
    - if not @swottle.nil? and not @swottle.errors.nil? then
      - @swottle.errors.each do |error|
        %span.error= error
%div.latest.box 
  %h3 Latest swottles
  - if Swottle.count == 0 then
    No swottle founds
  - for swottle in Swottle.latest
    %div.swottle
      %p.message= swottle.message
      %p.meta
        %a{:href => "#{Url}/get/#{swottle.id}"} #
        Written the
        %span.date= swottle.created_at.strftime("%m/%d/%Y")
        at
        %span.time= swottle.created_at.strftime("%H:%m")

@@get
%div.swottle.box
  - if not @swottle.nil? then
    %p.message= @swottle.message
    %p.meta
      %a{:href => "#{Url}/get/#{@swottle.id}"} #
      Written the
      %span.date= @swottle.created_at.strftime("%m/%d/%Y")
      at
      %span.time= @swottle.created_at.strftime("%H:%m")
  - else
    No swottle founds
- if not @swottle.nil? then
  %div.comments.box
    %h3 Comments
    %form{:action => "#{Url}/comment/#{@swottle.id}", :method => "post"}
      - if not @comment.nil? then
        - message = @comment.message
        - author = @comment.author
      %label{:for => "message"} Your comment:
      %textarea#message{:name => "message"}= message
      %label{:for => "author"} Your name:
      %input#author{:type => "text", :name => "author", :value => author}
      %input{:type => "submit", :value => "Send"}
      - if not @comment.nil? and not @comment.errors.nil? then
        - @comment.errors.each do |error|
          %span.error= error
    - for comment in @swottle.comments
      %div.comment
        %a{:name => comment.id}
        %p.message= comment.message
        %p.meta
          %a{:href => "#{Url}/get/#{@swottle.id}##{comment.id}"} #
          Written the
          %span.date= comment.created_at.strftime("%m/%d/%Y")
          at
          %span.time= comment.created_at.strftime("%H:%m")
          by
          %span.author= comment.author

@@dev
%div.box.dev
  %h2 Developers
  %h3 API to get random swottle
  %ul.api
    %li
      %a{:href => "#{Url}/random/xml"} XML
    %li
      %em // TODO : Add JSON API
  %h3 Integration
  %p.examples
    %em // TODO : Add examples of integration (PHP & JS)

@@about
%div.box.about
  %h2 About us
  %p
    %em // TODO (or not)
  %h3 Contact us
  %ul.contact
    %li
      %a{:href => "mailto:taziden@flexiden.org"} Mister T.
    %li
      %a{:href => "mailto:mickael@blizzart.net"} Mister B.
  %p
    %em // TODO : do a beautiful contact form

@@ stylesheet
*
  :margin 0px
  :padding 0px
body
  :color #000
  :background #E7E7E6
  :font-family "Segoe UI","Lucida Grande",Arial,sans-serif
  :padding 20px
  :font-size 13px
  :width 720px
  :margin auto
h1 a
  :color #373737
  :text-decoration none
  :font-family "Trebuchet MS",Verdana,Sans-Serif
  :font-size 2.3em
h1 a:hover
  :color #000
h1
  :width 200px
  :float left
h3
  :color #333
#main
  :clear both
.box
  :background #FFF
  :border-top 4px #373737 solid
  :padding 10px
  :margin-bottom 20px
  :width 450px
.sidebar
  :width 200px
  :float right
  :clear right
.topbar
  :float right
.topbar li
  :display inline
  :margin 5px
.topbar a
  :color #000
  :text-decoration none
  :font-weight bold
  :border-top 4px #FFF solid
.topbar a:hover
  :border-top-color #373737
.new label, .new input[type=submit], .comments label, .comments input[type=submit]
  :display block
  :margin-top 10px
.new input[type=text], .new textarea, .comments input[type=text], .comments textarea
  :width 440px
.new textarea, .comments textarea
  :height 100px
.new input[type=submit], .comments input[type=submit]
  :background #4A4A4A
  :border none
  :padding 2px 5px
  :-moz-border-radius 3px
  :color #EEE
.new .description
  :color #B2A3A3
.new input[type=submit]:hover, .comments input[type=submit]:hover
  :color #FFF
.latest .swottle, .comments .comment
  :margin-top 10px
  :border-top 1px solid #EEE
  :padding-top 10px
.swottle .message, .comment .message
  :margin-bottom 10px
#main .swottle .meta, #main .swottle .meta a, #main .comment .meta, #main .comment .meta a
  :color #B2A3A3
  :font-size 11px
  :text-decoration none
#foot
  :clear both
  :color #B2A3A3
  :font-size 11px
#foot a, #foot a:hover
  :text-decoration none
  :color #B2A3A3
.error
  :display block
  :text-align right
  :color #FF0000
h2
  :margin-bottom 10px
.sidebar p, .about p, .dev p, ul
  :margin 10px 0
ul
  :margin-left 20px
#main a
  :color #333
#main a:hover
  :background #333
  :color #FFF
  :text-decoration none
