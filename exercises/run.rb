require "bundler/setup"
require "pry"
require "rom-repository"

require_relative "setup"

MIGRATION = Persistence.db.migration do
  change do
    create_table :authors do
      primary_key :id
      column :name, :text, null: false
    end

    create_table :articles do
      primary_key :id
      foreign_key :author_id, :authors
      column :title, :text, null: false
      column :published, :boolean, null: false, default: false
    end
  end
end

class AuthorsRepo < ROM::Repository[:authors]
  commands :create
end

class ArticlesRepo < ROM::Repository[:articles]
  commands :create, update: :by_pk

  def by_pk(id)
    articles.by_pk(id).one
  end

  def listing
    articles.combine(:author).published.to_a
  end

  def publish(author, article)
    articles
      .changeset(:create, article)
      .map { |attrs| attrs.merge(published: true) }
      .associate(author)
      .commit
  end

  def unpublish(article)
    articles
      .by_pk(article.id)
      .changeset(:update, article)
      .map { |attrs| attrs.to_h.merge(published: false) }
      .commit
  end
end

if $0 == __FILE__
  # Start with a clean database each time
  Persistence.reset_with_migration(MIGRATION)
  Persistence.finalize

  authors_repo = AuthorsRepo.new(Persistence.rom)
  articles_repo = ArticlesRepo.new(Persistence.rom)

  first_author = authors_repo.create(name: "Sir Edward")
  second_author = authors_repo.create(name: "Lt Malcom")

  published_1 = articles_repo.create(title: "My first article", published: true, author_id: first_author.id)
  published_2 = articles_repo.create(title: "My second article", published: true, author_id: second_author.id)
  draft_1     = articles_repo.create(title: "First draft", published: false, author_id: first_author.id)
  published_3 = articles_repo.update(draft_1.id, title: "Third article", published: true)

  articles_list = articles_repo.listing.to_a
end
