module CustomerSeeder

  extend self

  CUSTOMERS = ["Pleasant Valley, California - SIS DPL", "Colorado - FIN PUB DPL"]

  def seed
    CUSTOMERS.each { |name| Customer.where(name: name).first_or_create! }
  end

end