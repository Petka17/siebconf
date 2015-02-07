class String

  def replace_char
    gsub("&", "&am;").
    gsub("/", "&s;").
    gsub("\\","&b;").
    gsub("|", "&v;").
    gsub("?", "&q;").
    gsub("*", "&a;").
    gsub("<", "&l;").
    gsub(">", "&g;").
    gsub(":", "&c;").
    gsub("\"","&q;")
  end

end

