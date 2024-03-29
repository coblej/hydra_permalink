require "hydra_permalink/version"
require "active_support/all"

module HydraPermalink

    extend ActiveSupport::Concern

    class Generator
      attr_accessor :proc

      def initialize
        @proc = Proc.new { |obj, target| nil }
      end

      def permalink_for(obj)
        url = case obj
        when MediaObject then media_object_url(obj.pid)
        when MasterFile  then pid_section_media_object_url(obj.mediaobject.pid, obj.pid)
        else raise ArgumentError("Cannot make permalink for #{obj.class}")
        end
        @proc.call(obj, url)
      end
    end

    @@generator = Generator.new
    def self.permalink_for(obj)
      @@generator.permalink_for(obj)
    end

    # Permalink.on_generate do |obj|
    #   permalink = (... generate permalink ...)
    #   return permalink
    # end
    def self.on_generate(&block)
      @@generator.proc = block
    end

    def permalink(query_vars = {})
      val = self.relationships(:has_permalink).first
      if val && query_vars.present?
        val = "#{val}?#{query_vars.to_query}"
      end
      val ? val.to_s : nil
    end

    def permalink=(value)
      self.remove_relationship(:has_permalink, nil)
      if value.present?
        self.add_relationship(:has_permalink, value, true)
      end
    end

    # wrap this method; do not use this method as a callback
    # if it returns false it will skip the rest of the items in the callback chain

    def ensure_permalink!
      updated = false

      begin
        link = self.permalink
        if link.blank?
          link = Permalink.permalink_for(self)
        end
      rescue Exception => e
        link = nil
        logger.error "Permalink.permalink_for() raised an exception for #{self.inspect}: #{e}"
      end

      if link.present? and not (self.permalink == link)
        self.permalink = link
        updated = true
      end

      updated
    end

end
