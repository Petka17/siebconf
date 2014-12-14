class Hash

  def get_string_attr
    select do |key, value| 
      value.is_a? String 
    end.reject do |key, value| 
      ["NAME", "PROJECT", "UPDATED", "UPDATED_BY", "CREATED", "CREATED_BY"].include?(key) or key.start_with?("_") 
    end
  end

  def get_array_attr
    select { |key, value| value.is_a? Array }
  end

end