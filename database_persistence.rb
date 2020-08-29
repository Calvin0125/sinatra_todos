require "pg"
require 'pry-byebug'
class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1"
    puts "#{sql}: #{id}"
    result = query(sql, id)
    tuple = result.first
    list_id = tuple["id"].to_i
    todos = find_todos_for_list(list_id)
    {id: tuple["id"], name: tuple["name"], todos: todos}
  end

  def all_lists
    sql = "SELECT * FROM lists"
    result = query(sql)
    result.map do |tuple|
      list_id = tuple["id"].to_i
      todos = find_todos_for_list(list_id)
      {id: list_id, name: tuple["name"], todos: todos}
    end
  end

  def create_list(list_name)
    id = next_element_id(all_lists)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(id)
    query("DELETE FROM todos WHERE list_id = $1", id)
    query("DELETE FROM lists WHERE id = $1", id)
  end

  def create_todo(list_id, name)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2)"
    query(sql, name, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE "\
          "list_id = $2 AND id = $3"
    query(sql, new_status, list_id, todo_id)
  end

  def delete_todo(list_id, todo_id)
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2"
    query(sql, list_id, todo_id)
  end

  def mark_all_complete(list_id)
    sql = "UPDATE todos SET completed = 'true' WHERE list_id = $1"
    query(sql, list_id)
  end

  def update_list_name(id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_name, id)
  end

  private

  def find_todos_for_list(list_id)
    todo_sql = "SELECT * FROM todos WHERE list_id = $1"
    todos_result = query(todo_sql, list_id)
    
    todos_result.map do |todo_tuple|
      completed = todo_tuple["completed"] == "t"
      { id: todo_tuple["id"].to_i, 
        name: todo_tuple["name"], 
        completed: completed }
    end
  end

  def next_element_id(elements)
    max = elements.map { |todo| todo[:id] }.max || 0
    max + 1
  end
end