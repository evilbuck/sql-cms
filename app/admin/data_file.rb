ActiveAdmin.register DataFile do

  scope "All", :with_deleted
  # For some reason, this doesn't use AR.all ...
  # scope "Undeleted Only", :all
  # ... hence this:
  scope "Undeleted Only", :sans_deleted, default: true
  scope "Deleted Only", :only_deleted

  actions :all

  config.add_action_item :undelete, only: :show, if: proc { resource.deleted? } do
    link_to "Undelete", undelete_data_file_path(resource), method: :put
  end

  permit_params :name, :metadata, :customer_id, :file_type, :supplied_s3_url #:s3_bucket_name, :s3_file_name

  filter :name, as: :string
  filter :customer, as: :select, collection: proc { Customer.order(:slug).all }
  filter :file_type, as: :select, collection: DataFile::FILE_TYPES
  filter :s3_bucket_name, as: :select

  # This may not work
  config.sort_order = 'customers.name_asc'

  index download_links: false do
    # id_column
    column(:name) { |data_file| auto_link(data_file) }
    column(:customer)
    column(:file_type)
    column(:s3_bucket_name)
    column(:s3_file_name)
  end

  show do
    attributes_table do
      row :id
      row :name
      row :customer

      row :file_type
      row :metadata

      row :s3_bucket_name
      row :s3_file_name

      row :created_at
      row :updated_at
      row :deleted_at
    end

    active_admin_comments

    panel "History" do
      render partial: 'admin/shared/history', locals: { context: self, associated: data_file }
    end
  end

  # FIXME - Build a browser for files already on S3, from which to select, perhaps using this example: https://www.topdan.com/ruby-on-rails/aws-s3-browser.html

  form do |f|
    inputs 'Details' do
      # This might be useful elsewhere; keep it around
      # semantic_errors *f.object.errors.keys
      input :customer, as: :select, collection: Customer.order(:slug).all
      input :name, as: :string
      input :file_type, as: :select, collection: DataFile::FILE_TYPES
      # FIXME - MAKE THIS WORK
      # input :metadata, as: :string # probably YML instead would be better; unimportant now
      input :supplied_s3_url, label: "S3 File URL", hint: "You may use either https:// format or s3:// format for this URL"
    end
    f.actions
  end

  controller do

    def scoped_collection
      DataFile.joins(:customer)
    end

    def find_resource
      DataFile.with_deleted.find_by(id: params[:id])
    end

    def action_methods
      result = super
      # Don't show the destroy button if the DataFile is already destroyed, since a 2nd destroy will physically nuke the record
      result -= ['destroy'] if action_name == 'show' && resource.deleted?
      result
    end

  end

  member_action :undelete, method: :put do
    resource.recover
    flash[:notice] = "DataFile Restored!"
    redirect_to data_file_path(resource)
  end

end
