module CustomerSeeder

  extend self

  CUSTOMERS = ["Pleasant Valley, California", "Colorado"]

  def seed
    CUSTOMERS.each { |name| Customer.where(name: name).first_or_create! }
  end

end
