class CreateMemes < ActiveRecord::Migration[8.0]
  def change
    create_table :memes do |t|
      t.string :title
      t.string :image_url
      t.string :source_url
      t.string :category
      t.integer :view_count

      t.timestamps
    end
  end
end
