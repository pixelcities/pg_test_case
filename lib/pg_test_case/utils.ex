defmodule PgTestCase.Utils do
  @moduledoc false

  require Logger

  # TODO: Do not rely on PATH
  def initdb_cmd(dir, user) do
    case System.cmd("initdb", [
      "-D", Path.join(dir, "data"),
      "-U", user,
      "-A", "trust"
    ]) do
      {_, 0} -> :ok
      {out, status} ->
        Logger.debug(out)
        {:error, status}
    end
  end

  def start_postgres(dir, pg_port) do
    path = System.find_executable("postgres")
    port =
      Port.open({:spawn_executable, path}, [:stderr_to_stdout, :binary, args: [
        "-D", Path.join(dir, "data"),
        "-k", Path.join(dir, "run"),
        "-p", to_string(pg_port),
        "-h", "127.0.0.1",
        "-F",
        "-c", "logging_collector=off"
      ]])

    wait_until_ready(port)
  end

  def stop_postgres(dir) do
    # Closing the communication channel doesn't actually kill the
    # postgres server. Use pg_ctl instead.
    case System.cmd("pg_ctl", [
      "stop",
      "-D", Path.join(dir, "data"),
      "-m", "fast"
    ]) do
      {_, 0} -> :ok
      {out, status} ->
        Logger.warning("Unable to stop postgres server automatically. The server process may have been leaked.")
        Logger.debug(out)
        {:error, status}
    end
  end

  def cleanup(dir) do
    stop_postgres(dir)
    File.rm_rf!(dir)

    # Also perform a quick check to see if there are any zombie process due to a previous bad exit
    dirs =
      System.tmp_dir!()
      |> Path.join("PgTestCase.*/data/postmaster.pid")
      |> Path.wildcard()

    # Just stop the postgres cluster using up a process / port, but let's not call `rm -rf` on it
    Enum.each(dirs, fn old_dir ->
      basepath =
        old_dir
        |> Path.split()
        |> Enum.drop(-2)
        |> Path.join()

      stop_postgres(basepath)
    end)
  end

  def mkdtemp do
    dir =
      System.tmp_dir!()
      |> Path.join("PgTestCase." <> Base.encode32(:rand.bytes(4), padding: false))

    if File.exists?(dir) do
      mkdtemp()

    else
      File.mkdir_p!(Path.join(dir, "run"))
      dir
    end
  end

  def get_available_port do
    {:ok, socket} = :socket.open(:inet, :stream)
    :socket.bind(socket, %{:family => :inet, :port => 0})
    {:ok, %{port: port}} = :socket.sockname(socket)
    :ok = :socket.close(socket)

    port
  end

  defp wait_until_ready(port) do
    receive do
      {^port, {:data, data}} ->
        unless String.contains?(data, "database system is ready to accept connections") do
          wait_until_ready(port)
        end
    end
  end
end
