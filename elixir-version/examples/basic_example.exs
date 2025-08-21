defmodule BasicExample do
  @moduledoc """
  Basic usage example for LibSQL Client.
  
  This example demonstrates:
  - Connecting to a Turso database
  - Creating tables
  - Inserting data
  - Querying data
  - Using transactions
  """

  alias LibsqlClient

  def run do
    # Configuration - replace with your actual database URL and token
    database_url = "libsql://your-database.turso.io"
    auth_token = "your-auth-token"
    
    IO.puts("🚀 Starting LibSQL Client Basic Example")
    
    # Connect to the database
    IO.puts("📡 Connecting to database...")
    {:ok, conn} = LibsqlClient.connect(database_url, auth_token: auth_token)
    IO.puts("✅ Connected successfully!")
    
    # Create a users table
    IO.puts("🏗️  Creating users table...")
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      age INTEGER,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
    """
    
    {:ok, _result} = LibsqlClient.execute(conn, create_table_sql)
    IO.puts("✅ Table created successfully!")
    
    # Clear any existing data
    {:ok, _} = LibsqlClient.execute(conn, "DELETE FROM users")
    
    # Insert some sample data
    IO.puts("📝 Inserting sample data...")
    users = [
      ["Alice Johnson", "alice@example.com", 28],
      ["Bob Smith", "bob@example.com", 35],
      ["Carol Davis", "carol@example.com", 22],
      ["David Wilson", "david@example.com", 41]
    ]
    
    for [name, email, age] <- users do
      {:ok, _result} = LibsqlClient.execute(conn, 
        "INSERT INTO users (name, email, age) VALUES (?, ?, ?)",
        [name, email, age])
      IO.puts("  ➕ Added: #{name}")
    end
    
    # Query all users
    IO.puts("📋 Querying all users...")
    {:ok, result} = LibsqlClient.execute(conn, "SELECT * FROM users ORDER BY name")
    
    IO.puts("👥 Found #{result.num_rows} users:")
    for row <- result.rows do
      [id, name, email, age, created_at] = row
      IO.puts("  • #{name} (#{email}) - Age: #{age}, ID: #{id}")
    end
    
    # Query with parameters
    IO.puts("\n🔍 Querying users over 30...")
    {:ok, result} = LibsqlClient.execute(conn, 
      "SELECT name, age FROM users WHERE age > ? ORDER BY age DESC",
      [30])
    
    for [name, age] <- result.rows do
      IO.puts("  • #{name} - Age: #{age}")
    end
    
    # Transaction example
    IO.puts("\n💳 Transaction example...")
    
    result = LibsqlClient.transaction(conn, fn conn ->
      # Insert a new user
      {:ok, _} = LibsqlClient.execute(conn, 
        "INSERT INTO users (name, email, age) VALUES (?, ?, ?)",
        ["Eve Martinez", "eve@example.com", 33])
      
      # Update another user
      {:ok, _} = LibsqlClient.execute(conn, 
        "UPDATE users SET age = ? WHERE email = ?",
        [29, "alice@example.com"])
      
      # Query the changes
      {:ok, count_result} = LibsqlClient.execute(conn, "SELECT COUNT(*) FROM users")
      [[count]] = count_result.rows
      
      IO.puts("  ✅ Transaction completed - Total users: #{count}")
      {:ok, count}
    end)
    
    case result do
      {:ok, count} -> 
        IO.puts("✅ Transaction successful! Total users: #{count}")
      {:error, reason} -> 
        IO.puts("❌ Transaction failed: #{inspect(reason)}")
    end
    
    # Final query to show all users
    IO.puts("\n📊 Final user list:")
    {:ok, result} = LibsqlClient.execute(conn, 
      "SELECT name, email, age FROM users ORDER BY name")
    
    for [name, email, age] <- result.rows do
      IO.puts("  • #{name} (#{email}) - Age: #{age}")
    end
    
    # Cleanup
    IO.puts("\n🧹 Cleaning up...")
    {:ok, _} = LibsqlClient.execute(conn, "DROP TABLE users")
    LibsqlClient.close(conn)
    
    IO.puts("🎉 Example completed successfully!")
  end
  
  def run_with_local_file do
    IO.puts("🗄️  Running with local SQLite file...")
    
    # Connect to a local SQLite file
    {:ok, conn} = LibsqlClient.connect("file:///tmp/example.db")
    
    # Create and use a simple table
    {:ok, _} = LibsqlClient.execute(conn, """
      CREATE TABLE IF NOT EXISTS notes (
        id INTEGER PRIMARY KEY,
        title TEXT,
        content TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    """)
    
    {:ok, _} = LibsqlClient.execute(conn, 
      "INSERT INTO notes (title, content) VALUES (?, ?)",
      ["My First Note", "This is a test note using local SQLite."])
    
    {:ok, result} = LibsqlClient.execute(conn, "SELECT * FROM notes")
    IO.puts("📝 Found #{result.num_rows} notes in local database")
    
    LibsqlClient.close(conn)
    IO.puts("✅ Local example completed!")
  end
end

# Uncomment to run the examples:
# BasicExample.run()
# BasicExample.run_with_local_file()