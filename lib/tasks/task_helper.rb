require 'csv'
require 'highline'

require "#{Rails.root}/config/initializers/dputs"

module TaskHelper

  extend self

  def ask(prompt, show_abort_message: true, required_response: 'yes', important: false)
    msg = prompt + (show_abort_message ? " Typing anything other than '#{required_response}' will abort." : " You must type #{required_response} to do so.")
    if important # Color important text RED and highlight the required response
      msg = "\e[31m#{msg}\e[0m"
      msg.sub!(/'#{required_response}'/, "\e[47m'#{required_response}'\e[49m")
    end
    HighLine.new.ask(msg) =~ /\A#{required_response}\Z/i
  end

  def with_timing(what)
    start = Time.now
    puts "Commencing #{what} ..."
    result = yield
    time = Time.at(Time.now - start).getutc.strftime("%H:%M:%S")
    puts
    puts "Finished #{what} in #{time}."
    result
  end

end
