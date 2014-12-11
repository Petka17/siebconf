module HashsHelper

  def server_role_params_value value
    if value.class == Array
      value.join(" ")
    else 
      value
    end
  end

  def server_hash_params_value hash, field
    hash[field] if hash
  end

  def create_server_role_hash param_roles
    param_roles.each { |key, value| { name: key, parameters: value } if value[:assoc] } - [nil]
  end

end