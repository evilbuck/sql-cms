# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  first_name             :string           not null
#  last_name              :string           not null
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :inet
#  last_sign_in_ip        :inet
#  deleted_at             :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#

describe User, type: :model do

  let!(:user) { create(:user) }

  describe "validations" do
    [:email, :first_name, :last_name].each do |att|
      it { should validate_presence_of(att) }
    end

    context "with a user already extant" do
      let!(:subject) { user }
      it { should validate_uniqueness_of(:email).case_insensitive }
    end

    it "should accept valid email addresses" do
      %w[foo@bar.baz foo_a@bar.baz foo.bar@baz.com foo+bar@baz.com FoO@BaR.com].each do |valid_email|
        user.email = valid_email
        expect(user).to be_valid
      end
    end

    it "should reject invalid email addresses" do
      %w[foo@bar,com user.com @foo.com user@user@com user@.com user@user.].each do |invalid_email|
        user.email = invalid_email
        expect(user).to_not be_valid
      end
    end

    it "should not allow email addresses with semicolons in them (Devise's lame email address validator does)" do
      expect(build(:user, email: "foo;bar@nowhere.com")).to_not be_valid
    end

  end

  describe "associations" do
    it { should have_many(:notifications) }
    it { should have_many(:observed_workflow_configurations).through(:notifications).source(:workflow_configuration) }
    it { should have_many(:runs) }
  end

  describe "instance methods" do

    it "should have a #full_name method that concats the first and last names" do
      expect(user.full_name).to eq("#{user.first_name} #{user.last_name}".squish)
    end

  end

  describe "class methods" do

    context "metaprogrammed methods" do
      it "should have 1 memoized user, and a flush method" do
        expect(User.admin).to be_nil
        expect { UserSeeder.seed }.to_not raise_error

        admin = User.admin
        expect(admin).to be_a(User)
        expect(User.instance_variable_get(:"@admin")).to eq(admin)

        User.flush_cache
        expect(User.instance_variable_get(:"@admin")).to be_nil
      end
    end

  end

end
