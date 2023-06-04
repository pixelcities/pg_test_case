defmodule PgTestCase do
  @moduledoc """
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
           @repo.stop() # Assumes a supervisor will restart the repo
        end

        unless is_nil(@prefix) do
          @repo.query("CREATE SCHEMA IF NOT EXISTS \"#{@prefix}\";")
        end

        on_exit(fn ->
          Logger.info("Cleaning up database \"#{@database}\"")

          # TODO: Not called when mix test failes badly (e.g. syntax error)
          stop_postgres(dir)
          File.rm_rf!(dir)
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
