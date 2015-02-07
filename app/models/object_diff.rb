class ObjectDiff

  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :siebel_configuration
  belongs_to :configuration_object

  field :source, type: Array

  def create_diff orig_obj, new_obj
    self.source = orig_obj.clone
    check_diff self.source, new_obj
  end

  private

    def check_diff orig_obj, new_obj
      orig_obj.each do |orig_elem|
        orig_elem["_orig_obj"]    = true
        orig_elem["_new_obj"]     = false
        orig_elem["_changed_obj"] = true
        
        mark_as_delete(orig_elem) unless new_obj.detect{ |elem| elem["NAME"] == orig_elem["NAME"] }
      end

      new_obj.each do |new_elem|
        orig_elem = orig_obj.detect{ |elem| elem["NAME"] == new_elem["NAME"] }


        if orig_elem
          orig_elem["_new_obj"] = true
          orig_elem["_changed_attr"] = false
          orig_elem["_delete_obj"]  = false

          if orig_elem["_sha1_obj"] == new_elem["_sha1_obj"]
            orig_elem["_changed_obj"] = false
          else

            unless orig_elem["_sha1_attr"] == new_elem["_sha1_attr"]
              orig_elem["_changed_attr"] = true

              new_attr = {} 
              orig_elem.get_string_attr.each do |key, value| 
                new_attr["_new_#{key}"] = ""
                new_attr["_orig_#{key}"] = value.dup
                new_attr[key] = ""
              end
              
              new_elem.get_string_attr.each do |key, value|
                new_attr["_new_#{key}"] = value
                new_attr[key] = value
                new_attr.except!("_new_#{key}", "_orig_#{key}", key) if new_attr["_orig_#{key}"] == value
              end
              orig_elem.merge!(new_attr) unless new_attr.empty?
            end

            new_attr = {}
            orig_elem.get_array_attr.each do |key, value|
              new_attr["_orig_#{key}"]    = true
              new_attr["_new_#{key}"]     = false
              new_attr["_changed_#{key}"] = true
            end
            orig_elem.merge!(new_attr)

            new_elem.get_array_attr.each do |key, value|
              orig_elem["_new_#{key}"] = true

              if orig_elem["_sha1_#{key}"]
                unless orig_elem["_sha1_#{key}"] == new_elem["_sha1_#{key}"]
                  check_diff orig_elem[key], new_elem[key]
                else
                  orig_elem["_changed_#{key}"] = false
                end
              else
                orig_elem["_orig_#{key}"] = false
                orig_elem["_changed_#{key}"] = true
                orig_elem[key] = value.dup.each{ |e| mark_as_changed(e) }
              end
            end

            orig_elem.get_array_attr.select{ |key, value| orig_elem["_orig_#{key}"] and !orig_elem["_new_#{key}"] }.each do |key, value|
              value.each{ |e| mark_as_delete e }
            end
          end
        else
          orig_obj << mark_as_changed(new_elem)
        end
      end
    end

    def mark_as_changed elem
      elem["_orig_obj"]    = false
      elem["_new_obj"]     = true
      elem["_changed_obj"] = true
      elem["_delete_obj"]  = false

      new_attr = {}
      elem.get_string_attr.each do |key, value| 
        new_attr["_new_#{key}"] = value.dup
        new_attr["_orig_#{key}"] = ""
      end
      elem.merge!(new_attr)
      elem["_changed_attr"] = true

      new_attr = {}
      elem.get_array_attr.each do |key, value|
        new_attr["_orig_#{key}"]    = false
        new_attr["_new_#{key}"]     = true
        new_attr["_changed_#{key}"] = true
        value.each{ |child_obj_elem| mark_as_changed child_obj_elem }
      end

      elem.merge!(new_attr)
    end

    def mark_as_delete elem
      elem["_orig_obj"]    = true
      elem["_new_obj"]     = false
      elem["_changed_obj"] = true
      elem["_delete_obj"]  = true

      new_attr = {} 
      elem.get_string_attr.each do |key, value| 
        new_attr["_new_#{key}"] = ""
        new_attr["_orig_#{key}"] = value.dup
        new_attr[key] = ""
      end
      elem.merge!(new_attr) unless new_attr.empty?     
      elem["_changed_attr"] = true

      new_attr = {}
      elem.get_array_attr.each do |key, value|
        new_attr["_orig_#{key}"]    = true
        new_attr["_new_#{key}"]     = false
        new_attr["_changed_#{key}"] = true
        value.each{ |child_obj_elem| mark_as_delete child_obj_elem }
      end

      elem.merge!(new_attr)
    end
end
