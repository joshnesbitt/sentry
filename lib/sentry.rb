# Sentry

class Object
  
  def for_user(subject, options = {})
    puts "for_user called [self=#{self}, subject=#{subject}]"
    Sentry::Factory.new.create(self, subject, options)
  end
  alias :as_sentry_for :for_user

end

# TODO:
# rspec
# error handling!
# break into packages
# refactor
# rails extensions

=begin

# don't allow privs to exist in more than 1 place
Sentry.privelages do
  # resets all privelages
  createable do
    new
    create
  end
  readble do
    index
    show
    read
  end

  # iterate over ancestors and rebuild methods

end

=end

module Sentry
  
  # Priveleges
  ACTIONS = {
    :creatable  => [:new, :create],
    :readable   => [:index, :show, :read],
    :updatable  => [:edit, :update],
    :deletable  => [:destroy, :delete]
  }

  class Factory

    def create(source, subject, opts)
      puts ":: create called [source=#{source}, subject=#{subject}, opts=#{opts}]"
      mixin_name = opts[:mixin_name] || "#{source.class}Sentry"
      mixin = mixin_name.constantize

      sentry = mixin.new(source, subject, opts)

      # puts sentry.class
      # puts "printing methods..."
      # check it's a sentry
      methods = mixin.public_instance_methods - Object.public_instance_methods - [:source, :subject, :opts]

      methods.each do |m|
        puts "adding method #{m}"
        add_method sentry, m
      end

      
      source
    end

    private

    def add_method(sentry, name)   
      unless sentry.source.respond_to?(name)
        sentry.source.class_eval do
          puts "::: DEFIING #{name} on #{sentry.source.class}"
          define_method name do
            sentry.send(name)           
          end
        end
      else
        puts "method already defined #{name}"
        raise "#{sentry.source} already responds to #{name}!"
      end
    end 

  end

  class Base

    attr_reader :source, :subject, :opts

    def initialize(source, subject, opts)
      @source = source
      @subject = subject
      @opts = opts
      if opts[:authorize]
        authorize!(opts[:authorize])
      end
    end
    
    Sentry::ACTIONS.each do |k, v|
      method = "#{k}?"
      define_method method do
        false # or a default from options
      end
    end
    
    protected

    def sources
      [@source]
    end

    def authorized(privs)
      privs = [*privs]
      sources.select { |s| privs.all? { |p| s.send "#{p}?" } }
    end

    def authorized?(privs)
      authorized(priv).size == sources.sizes
    end

    def unauthorized(privs)
      sources - authorized(privs)
    end

    def unauthorized?(privs)
      !authorized(privs)
    end

    def authorize!(privs)
      raise "not authorized!" if unauthorized?(privs)
    end
    
  end

end

class ArraySentry < Sentry::Base
  
  def initialize(source, subject, opts = {})
    puts "init array sentry"
    source.map! { |m| m.as_sentry_for(subject) }
    super source, subject, opts
  end

  Sentry::ACTIONS.each do |k, v|
    method = "#{k}?"
    define_method method do
      sources.all?(&:"#{method}")
    end
  end

  protected

  def sources
    @source
  end

end
