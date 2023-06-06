defmodule PgTestCase do
  @moduledoc """
  PgTestCase is a small utility to manage the data lifecycle during tests

  The module creates a temporary postgres server for your test session, runs your Ecto
  migrations, and finally deletes the postgres server after all the tests have completed.

  This module is meant to be used with ExUnit and Ecto, and specifically Ecto backed by
  postgres. It will restart the Ecto Repo with the temporary database configuration, so that
  tests can use Ecto.Repo just like normal.

  ## Use

  To get started, simply use the module and tell it about your application and Ecto.Repo. It will
  in turn use ExUnit.Case, which allows you to define test cases using `setup` and/or `setup_all`.

  In this example we will tell ExUnit.Case to run `:initdb` and `:migrations`, to start the temporary
  database and run the migrations, respectively.

      defmodule MyAppTest do
        use PgTestCase,
          otp_app: :my_app,
          repo: MyApp.Repo

        setup_all [:initdb, :migrations]

        test "validates database model" do
          assert true
        end
      end

  It's advised to pass the test case functions to `setup_all`, so that PgTestCase does not have to
  recreate the database for each individual test. After the tests complete, ExUnit.Case will call
  the PgTestCase cleanup function, which will stop and delete the temporary database server.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app Keyword.fetch!(opts, :otp_app)
      @repo Keyword.fetch!(opts, :repo)

      @database Keyword.get(opts, :database, "postgres")
      @user Keyword.get(opts, :user, "postgres")
      @prefix Keyword.get(opts, :prefix)

      use ExUnit.Case

      require Logger

      def initdb(_context) do
        import PgTestCase.Utils

        Logger.info("Creating database \"#{@database}\"")

        dir = mkdtemp()
        port = get_available_port()

        initdb_cmd(dir, @user)
        start_postgres(dir, port)

        # Hijack the repo config
        Application.put_env(@otp_app, @repo,
          hostname: "127.0.0.1",
          port: port,
          username: @user,
          database: @database
        )

        repo = @repo.start_link()
        if match?({:error, {:already_started, _pid}}, repo) do
           @repo.stop() # Assume a supervisor will restart the repo
        end

        unless is_nil(@prefix) do
          @repo.query("CREATE SCHEMA IF NOT EXISTS \"#{@prefix}\";")
        end

        on_exit(fn ->
          Logger.info("Cleaning up database \"#{@database}\"")

          cleanup(dir)
        end)

        {:ok, postgres: %{
          hostname: "127.0.0.1",
          port: port,
          database: @database,
          username: @user
        }}
      end

      def migrations(%{postgres: _postgres} = _context) do
        Ecto.Migrator.run(@repo, :up, all: true, prefix: @prefix)

        :ok
      end
    end
  end
end
