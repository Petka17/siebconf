class ObjectDiff

  include Mongoid::Document
  include Mongoid::Timestamps

  # belongs_to :siebel_configuration
  # belongs_to :configuration_object

  field :source, type: Array

  def execute! new_obj_source
    check_diff self.source, new_obj_source
    upsert
  end

  private

    def check_diff orig_obj, new_obj
      # Set the main control attrib for all elements in the orig element array
      orig_obj.each do |orig_elem|
        set_sys_flags orig_elem, "elem", true, true, false, false, false
          
        # if an element is not in the new object mark it as deleted
        mark_as_delete(orig_elem) unless new_obj.detect{ |elem| elem["NAME"] == orig_elem["NAME"] }
      end

      # Process all new elements
      new_obj.each do |new_elem|
        # Detect the new element in the orig element array
        orig_elem = orig_obj.detect{ |elem| elem["NAME"] == new_elem["NAME"] }

        # If the new element is detected in th orig element array
        if orig_elem
          # Check the object sha1 keys for the new and orig element
          unless orig_elem["_sha1_elem"] == new_elem["_sha1_elem"]
            # the new element is differ from the orig element
            orig_elem["_changed_elem"] = true # the element was changed

            # Check attrib sha1 keys for the new and orig elements
            unless orig_elem["_sha1_attr"] == new_elem["_sha1_attr"]
              orig_elem["_changed_attr"] = true # the element attributes was changed

              # Create hash for current values of all attributes
              new_attr = {} 
              orig_elem.get_string_attr.each do |key, value| 
                new_attr["_new_val_#{key}"] = ""
                new_attr["_orig_val_#{key}"] = value.dup
                new_attr[key] = ""
              end
              
              # Update hash according to attributes of new element
              new_elem.get_string_attr.each do |key, value|
                new_attr["_new_val_#{key}"] = value.to_s
                new_attr[key] = value.to_s
                new_attr.except!("_new_val_#{key}", "_orig_val_#{key}", key) if new_attr["_orig_val_#{key}"] == value
              end

              # Insert hash to element
              orig_elem.merge!(new_attr) unless new_attr.empty?
            end

            # Check all child objects
            # Create hash for all child objects in orig element
            new_attr = {}
            orig_elem.get_array_attr.each do |key, value|
              set_sys_flags new_attr, key, true, false, false
            end
            orig_elem.merge!(new_attr)

            # For each object in new element
            new_elem.get_array_attr.each do |key, value|
              orig_elem["_new_#{key}"] = true # the child object is in new element

              # Check if the child object exists in the orig element
              if orig_elem[key]
                # Check the sha1 keys for the child objecta in the new and orig element
                unless orig_elem["_sha1_#{key}"] == new_elem["_sha1_#{key}"]
                  orig_elem["_changed_#{key}"] = true
                  # Invoke check_diff function recurcively
                  check_diff orig_elem[key], new_elem[key]
                end
              else
                # In case when the is no child object in the orig element
                orig_elem["_orig_#{key}"]    = false # the child object is not in orig element
                orig_elem["_changed_#{key}"] = true  # the child object is in new element
                # duplicate the value of the child object from new element to orig element and mark it as changed
                orig_elem[key] = value.dup.each{ |e| mark_as_changed(e) }
              end
            end

            # Mark all child objects as deleted if they are not in the new element
            orig_elem.get_array_attr.select{ |key, value| orig_elem["_orig_#{key}"] and !orig_elem["_new_#{key}"] }.each do |key, value|
              value.each{ |e| mark_as_delete e }
            end
          end
        else
          # In case when the element is not exist in the orig array
          orig_obj << mark_as_changed(new_elem.dup) # Duplicate new element to the orig array
        end
      end
    end

    def mark_as_changed elem
      set_sys_flags elem, "elem", false, true, true, false
      
      new_attr = {}
      elem.get_string_attr.each do |key, value| 
        new_attr["_new_val_#{key}"] = value.dup
        new_attr["_orig_val_#{key}"] = ""
      end
      elem.merge!(new_attr)
      elem["_changed_attr"] = true

      new_attr = {}
      elem.get_array_attr.each do |key, value|
        set_sys_flags new_attr, key, false, true, true
        value.each{ |child_obj_elem| mark_as_changed child_obj_elem }
      end

      elem.merge!(new_attr)
    end

    def mark_as_delete elem
      set_sys_flags elem, "elem", true, false, true, true

      new_attr = {} 
      elem.get_string_attr.each do |key, value| 
        new_attr["_new_val_#{key}"] = ""
        new_attr["_orig_val_#{key}"] = value.dup
        new_attr[key] = ""
      end
      elem.merge!(new_attr) unless new_attr.empty?     
      elem["_changed_attr"] = true

      new_attr = {}
      elem.get_array_attr.each do |key, value|
        set_sys_flags new_attr, key, true, false, true
        value.each{ |child_obj_elem| mark_as_delete child_obj_elem }
      end

      elem.merge!(new_attr)
    end

    private

      def set_sys_flags elem, key, orig_flg, new_flg, changed_flg, delete_flg = nil, attr_flg = nil
        elem["_orig_#{key}"]    = orig_flg    unless orig_flg.nil?
        elem["_new_#{key}"]     = new_flg     unless new_flg.nil?
        elem["_changed_#{key}"] = changed_flg unless changed_flg.nil?
        elem["_deleted_#{key}"] = delete_flg  unless delete_flg.nil?
        elem["_changed_attr"]   = attr_flg    unless attr_flg.nil?
      end
end
