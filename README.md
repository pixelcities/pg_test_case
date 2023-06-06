# PgTestCase

PgTestCase is a small utility to manage the data lifecycle during tests

The module creates a temporary postgres server for your test session, runs your Ecto
migrations, and finally deletes the postgres server after all the tests have completed.

This module is meant to be used with ExUnit and Ecto, and specifically Ecto backed by
postgres. It will restart the Ecto Repo with the temporary database configuration, so that
tests can use Ecto.Repo just like normal.


## Installation

Add `pg_test_case` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pg_test_case, "~> 0.1.0"}
  ]
end
```

Note that PgTestCase will create a temporary postgres server, which requires PostgreSQL (and related
utils) to be installed on your machine. Specifically, it may use the following executables: `initdb`,
`postgres`, and `pg_ctl`.


## Use

To get started, simply use the module and tell it about your application and Ecto.Repo. It will
in turn use ExUnit.Case, which allows you to define test cases using `setup` and/or `setup_all`.

In this example we will tell ExUnit.Case to run `:initdb` and `:migrations`, to start the temporary
database and run the migrations, respectively.

```elixir
defmodule MyAppTest do
  use PgTestCase,
    otp_app: :my_app,
    repo: MyApp.Repo

  setup_all [:initdb, :migrations]

  test "validates database model" do
    assert true
  end
end
```

