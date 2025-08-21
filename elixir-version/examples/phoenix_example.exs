defmodule PhoenixExample do
  @moduledoc """
  Phoenix/Ecto integration example for LibSQL Client.
  
  This example shows how to use LibSQL Client with Phoenix and Ecto,
  including schema definitions, migrations, and common operations.
  """

  # This would be in your Phoenix application

  # 1. Repository configuration (config/config.exs)
  """
  config :my_app, MyApp.Repo,
    adapter: LibsqlClient.Ecto.Adapter,
    url: "libsql://my-database.turso.io",
    auth_token: System.get_env("TURSO_AUTH_TOKEN"),
    pool_size: 10,
    timeout: 5000
  """

  # 2. Repository module (lib/my_app/repo.ex)
  defmodule MyApp.Repo do
    use Ecto.Repo,
      otp_app: :my_app,
      adapter: LibsqlClient.Ecto.Adapter
  end

  # 3. User schema (lib/my_app/user.ex)
  defmodule MyApp.User do
    use Ecto.Schema
    import Ecto.Changeset

    schema "users" do
      field :name, :string
      field :email, :string
      field :age, :integer
      field :is_active, :boolean, default: true
      
      has_many :posts, MyApp.Post

      timestamps()
    end

    @required_fields [:name, :email]
    @optional_fields [:age, :is_active]

    def changeset(user, attrs) do
      user
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_format(:email, ~r/@/)
      |> validate_length(:name, min: 2, max: 50)
      |> validate_number(:age, greater_than: 0, less_than: 150)
      |> unique_constraint(:email)
    end
  end

  # 4. Post schema (lib/my_app/post.ex)
  defmodule MyApp.Post do
    use Ecto.Schema
    import Ecto.Changeset

    schema "posts" do
      field :title, :string
      field :content, :text
      field :published, :boolean, default: false
      
      belongs_to :user, MyApp.User

      timestamps()
    end

    def changeset(post, attrs) do
      post
      |> cast(attrs, [:title, :content, :published, :user_id])
      |> validate_required([:title, :content, :user_id])
      |> validate_length(:title, min: 5, max: 100)
      |> foreign_key_constraint(:user_id)
    end
  end

  # 5. Migration (priv/repo/migrations/001_create_users.exs)
  defmodule MyApp.Repo.Migrations.CreateUsers do
    use Ecto.Migration

    def change do
      create table(:users) do
        add :name, :string, null: false
        add :email, :string, null: false
        add :age, :integer
        add :is_active, :boolean, default: true

        timestamps()
      end

      create unique_index(:users, [:email])
    end
  end

  # 6. Migration (priv/repo/migrations/002_create_posts.exs)
  defmodule MyApp.Repo.Migrations.CreatePosts do
    use Ecto.Migration

    def change do
      create table(:posts) do
        add :title, :string, null: false
        add :content, :text, null: false
        add :published, :boolean, default: false
        add :user_id, references(:users, on_delete: :delete_all), null: false

        timestamps()
      end

      create index(:posts, [:user_id])
      create index(:posts, [:published])
    end
  end

  # 7. Context module (lib/my_app/blog.ex)
  defmodule MyApp.Blog do
    import Ecto.Query, warn: false
    alias MyApp.Repo
    alias MyApp.{User, Post}

    # User functions
    def list_users do
      Repo.all(User)
    end

    def get_user!(id), do: Repo.get!(User, id)

    def create_user(attrs \\ %{}) do
      %User{}
      |> User.changeset(attrs)
      |> Repo.insert()
    end

    def update_user(%User{} = user, attrs) do
      user
      |> User.changeset(attrs)
      |> Repo.update()
    end

    def delete_user(%User{} = user) do
      Repo.delete(user)
    end

    def get_user_with_posts(id) do
      User
      |> where([u], u.id == ^id)
      |> preload(:posts)
      |> Repo.one()
    end

    # Post functions
    def list_posts do
      Post
      |> preload(:user)
      |> Repo.all()
    end

    def list_published_posts do
      Post
      |> where([p], p.published == true)
      |> preload(:user)
      |> order_by([p], desc: p.inserted_at)
      |> Repo.all()
    end

    def get_post!(id) do
      Post
      |> preload(:user)
      |> Repo.get!(id)
    end

    def create_post(attrs \\ %{}) do
      %Post{}
      |> Post.changeset(attrs)
      |> Repo.insert()
    end

    def update_post(%Post{} = post, attrs) do
      post
      |> Post.changeset(attrs)
      |> Repo.update()
    end

    def delete_post(%Post{} = post) do
      Repo.delete(post)
    end

    def publish_post(%Post{} = post) do
      update_post(post, %{published: true})
    end
  end

  # 8. Phoenix Controller (lib/my_app_web/controllers/user_controller.ex)
  defmodule MyAppWeb.UserController do
    use MyAppWeb, :controller
    alias MyApp.Blog

    def index(conn, _params) do
      users = Blog.list_users()
      render(conn, "index.html", users: users)
    end

    def show(conn, %{"id" => id}) do
      user = Blog.get_user_with_posts(id)
      render(conn, "show.html", user: user)
    end

    def create(conn, %{"user" => user_params}) do
      case Blog.create_user(user_params) do
        {:ok, user} ->
          conn
          |> put_flash(:info, "User created successfully.")
          |> redirect(to: Routes.user_path(conn, :show, user))

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, "new.html", changeset: changeset)
      end
    end
  end

  # 9. LiveView example (lib/my_app_web/live/user_live.ex)
  defmodule MyAppWeb.UserLive do
    use MyAppWeb, :live_view
    alias MyApp.Blog

    def mount(_params, _session, socket) do
      users = Blog.list_users()
      {:ok, assign(socket, users: users)}
    end

    def handle_event("delete", %{"id" => id}, socket) do
      user = Blog.get_user!(id)
      {:ok, _} = Blog.delete_user(user)
      
      users = Blog.list_users()
      {:noreply, assign(socket, users: users)}
    end

    def render(assigns) do
      ~H"""
      <div>
        <h1>Users</h1>
        <div id="users" phx-update="replace">
          <%= for user <- @users do %>
            <div id={"user-#{user.id}"} class="user-item">
              <span><%= user.name %> (<%= user.email %>)</span>
              <button phx-click="delete" phx-value-id={user.id}>Delete</button>
            </div>
          <% end %>
        </div>
      </div>
      """
    end
  end

  # 10. Example usage in IEx
  def demo_usage do
    """
    # Start your Phoenix app
    iex -S mix phx.server

    # In IEx console:
    alias MyApp.{Repo, Blog, User, Post}

    # Create users
    {:ok, alice} = Blog.create_user(%{name: "Alice", email: "alice@example.com", age: 28})
    {:ok, bob} = Blog.create_user(%{name: "Bob", email: "bob@example.com", age: 35})

    # Create posts
    {:ok, post1} = Blog.create_post(%{
      title: "Hello World", 
      content: "My first post!", 
      user_id: alice.id
    })

    {:ok, post2} = Blog.create_post(%{
      title: "Elixir is Great", 
      content: "Learning Elixir and Phoenix", 
      user_id: alice.id
    })

    # Publish a post
    {:ok, _} = Blog.publish_post(post1)

    # Query data
    Blog.list_users()
    Blog.list_published_posts()
    Blog.get_user_with_posts(alice.id)

    # Use Ecto queries directly
    import Ecto.Query
    
    Repo.all(from u in User, where: u.age > 30)
    
    Repo.all(
      from p in Post,
      join: u in User,
      on: p.user_id == u.id,
      where: p.published == true,
      select: {p.title, u.name}
    )
    """
  end
end