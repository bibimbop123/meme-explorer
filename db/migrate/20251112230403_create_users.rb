class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :oauth_provider
      t.string :oauth_uid
      t.string :encrypted_password
      t.jsonb :preferences

      t.timestamps
    end
  end
end
