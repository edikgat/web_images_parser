require "web_images_parser/version"
require 'nokogiri'
require 'open-uri'
require 'timeout'
require 'rest_client'

module WebImagesParser
  module ClassMethods

    IMAGE_PATTERN = /\.(?i:jpg|gif|png|jpeg)/
    module_function

    def doc
      @doc
    end

    def doc=(new_doc)
      @doc = new_doc
    end

    def images_url
      @images_url
    end

    def img_arr
      @img_arr
    end

    def img_arr=(new_img_arr)
      @img_arr = new_img_arr
    end


    def get_images_from_url(new_images_url)
      return nil unless url_valid?(new_images_url)
      @images_url = URI.parse(new_images_url)
      @img_arr = []
      @doc = Timeout::timeout(30) { Nokogiri::HTML( RestClient.get(@images_url.to_s)) }
      find_and_modify_images()      
      rescue TypeError, SocketError, Errno::ENOENT, OpenURI::HTTPError, Timeout::Error, URI::InvalidURIError
      nil
    end


    def find_and_modify_images
      @default_title = find_default_title
      # specific_urls_doc_modify
      find_images_in_url
      @img_arr.uniq {|a| a.first }            
    end

    def find_default_title
      default_title = ""
      if @doc.css("title").present?
        default_title = @doc.css("title").first.content
      end
      default_title
    end

    def find_images_in_tegs
      @doc.css("img").each do |img|
        title  = set_needed_title((img[:title] || img[:alt]), @default_title)
        push_url_to_array_if_it_necessary(img[:src], title, false)
      end
      @doc.css("a").each do |img|
        title = find_title(img)
        title  = set_needed_title(title, @default_title)
        push_url_to_array_if_it_necessary(img[:href], title)
      end
    end

    # def specific_urls_doc_modify
    #   # case @images_url.host
    #   # when 'www.ozon.ru'
    #   #   @doc.css("div.buy-together").remove
    #   # end
    # end
    def find_images_in_url
      case @images_url.host
      when "shop.lacoste.ru"
        @img_arr = take_js_shop_lacoste_images
      when 'www.ozon.ru'
        @img_arr = take_js_ozone_images
      when "www.sotmarket.ru"
        pattern = /img-sotmarket.ru\//
        subpattern = /(standart|65x65)\//
        replacement = '1200x1200/'
        find_images_in_tegs
        take_big_images(pattern, subpattern, replacement)
      when 'www.asos.com'
        pattern = /images.asos-media.com\/inv\/media\//
        subpattern = /xl./
        replacement = 'xxl.'
        find_images_in_tegs
        take_big_images(pattern, subpattern, replacement)
      when "www.yoox.com"
        pattern = /cdn\d{0,}.yoox.biz\//
        subpattern = /_\d{1,}_/
        replacement = '_14_'
        find_images_in_tegs
        take_big_images(pattern, subpattern, replacement)
      when 'www.mebelrama.ru'
        pattern = /static\d{0,}.mebelrama.ru/
        subpattern = /gallery|product/
        replacement = 'zoom'
        find_images_in_tegs
        take_big_images(pattern, subpattern, replacement)
      when 'www.wildberries.ru'
        pattern = /img\d{0,}.wildberries.ru/
        subpattern = /\/tm\/|\/mini\/|\/large\//
        replacement = '/big/'
        find_images_in_tegs
        take_big_images(pattern, subpattern, replacement)
      else
        find_images_in_tegs
      end
    end

    def take_big_images(pattern, subpattern, replacement)
      @img_arr.map! do |img_and_title|
        if img_and_title[0] =~ pattern
          img_and_title[0] = "#{$~.pre_match}#{ $~.to_s}#{$~.post_match.sub(subpattern, replacement)}"
        end
        img_and_title
      end
    end

    # def ozone_take_valid_js_urls(default_title, js_url_arr)
    #   # ozone_js_parse
    #   pattern = /(static|mmedia)\d{0,}.ozone.ru\//
    #   subpattern = /[a-z_]+\/\d{1,}.\w{3,4}/
    #   valid_js_url_arr = []
    #   first_part_old_images_arr = @img_arr.map do |img_and_title|
    #     if img_and_title[0] =~ pattern
    #       first_part = "#{$~.pre_match}#{ $~.to_s}#{$~.post_match.split(subpattern).first}"
    #       unless is_image?(first_part)
    #         first_part
    #       end
    #     end
    #   end
    #   first_part_old_images_arr = first_part_old_images_arr.uniq.compact
    #   js_url_arr.each do |js_url|
    #     first_part_old_images_arr.each do |first_part|
    #       valid_js_url_arr.push(["#{first_part}#{js_url}", default_title])
    #     end
    #   end
    #   valid_js_url_arr
    # end

    def take_js_shop_lacoste_images
      js_url_arr = shop_lacoste_js_parse
      first_part = "http://shop.lacoste.ru"
      take_valid_js_urls(@default_title.encode("UTF-8", "UTF-8", invalid: :replace), js_url_arr, first_part)
    end

    def take_js_ozone_images
      js_url_arr = ozone_js_parse
      first_part = "http://mmedia.ozone.ru/multimedia/"
      take_valid_js_urls(@default_title.encode("UTF-8", "Windows-1251", invalid: :replace), js_url_arr, first_part)
    end

    def take_valid_js_urls(default_title, js_url_arr, first_part)
      js_url_arr.map do |js_url|
        ["#{first_part}#{js_url}", default_title]
      end
    end

    def ozone_js_parse
      pattern = /var model/
      subpattern = /[a-z_]+\/\d{1,}.\w{3,4}/
      parse_js(pattern, subpattern)
    end

    def shop_lacoste_js_parse
      pattern = /var gallery/
      subpattern = /\/upload\/iblock\/[a-z0-9]{3}\/[a-z0-9]+\.(?i:png|jpg|gif|jpeg)/
      parse_js_lacost(pattern, subpattern)
    end

    def parse_js_lacost(pattern, subpattern)
      js_scripts_arr = @doc.css("script").map { |w| w.content }
      needed_string = js_scripts_arr.select do |q,w|
        w = q.encode("UTF-8", "UTF-8", invalid: :replace)
        w =~ pattern
      end
      if needed_string.present?
        needed_string = needed_string.first
        needed_string.encode!("UTF-8", "UTF-8", invalid: :replace)
        needed_string.gsub!(/[^a-zA-Z0-9\"\{\}\[\]\-\/\:\,\.\_\}]/,"")
        needed_string.scan(subpattern)
      end
    end

    def parse_js(pattern, subpattern)
      js_scripts_arr = @doc.css("script").map { |w| w.content }
      needed_string = js_scripts_arr.select do |q,w|
        w = q.encode("UTF-8", "UTF-8", invalid: :replace)
        w =~ pattern
      end
      if needed_string.present?
        needed_string = needed_string.first
        needed_string.encode!("UTF-8", "UTF-8", invalid: :replace)
        needed_string.scan(subpattern)
      end
    end
  


    def find_title(a_teg)
      return a_teg[:title] if a_teg[:title].present?
      if a_teg.css("img").present?
        a_teg.css("img").first[:title] || a_teg.css("img").first[:alt]
      end
    end

    def set_needed_title(title, default_title)
     if title.present?
       if title.valid_encoding?
        return ActionView::Base.full_sanitizer.sanitize(title, :tags=>[])
       else
        title = title.encode("UTF-8", "Windows-1251", invalid: :replace, replace: nil)
        ActionView::Base.full_sanitizer.sanitize(title, :tags=>[])
       end
     else
      if default_title.valid_encoding?
        ActionView::Base.full_sanitizer.sanitize(default_title, :tags=>[])
      else
        default_title = default_title.encode("UTF-8", "Windows-1251", invalid: :replace, replace: nil)
        ActionView::Base.full_sanitizer.sanitize(default_title, :tags=>[])
      end
     end
    end

    def push_url_to_array_if_it_necessary(custom_url, title, image_check = true)
      if  image_checking(custom_url, image_check)
        img_attr_arr = []
        if url_valid?(custom_url)
          img_attr_arr.push(custom_url)
          img_attr_arr.push(String(title))
          @img_arr.push img_attr_arr
        else   
          first_decode = URI.parse(URI.encode(custom_url.strip))
          valid_host_url = "#{@images_url.scheme}://#{@images_url.host}"
          valide_image_url = URI.join( valid_host_url, first_decode ).to_s
          if url_valid?(valide_image_url)
            valide_image_url = URI.unescape(valide_image_url)
            img_attr_arr.push(valide_image_url)
            img_attr_arr.push(String(title))
            @img_arr.push img_attr_arr
          end
        end
      end
    end

    def image_checking(custom_url, image_check)
      if image_check
        custom_url.present? && is_image?(custom_url)
      else
        custom_url.present?
      end
    end

    def url_valid?(custom_url)
      URI.parse(custom_url)
      custom_url =~ URI::regexp(["http", "https"])
      rescue URI::InvalidURIError
        nil
    end

    def is_image?(string)
      string =~ IMAGE_PATTERN
    end

  end
end
