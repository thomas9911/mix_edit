defmodule MixEdit.FakePackage do
  def get(nil, "testing", _) do
    {:ok, {200, %{"latest_stable_version" => "735.7"}, []}}
  end

  def get("myorg", "testing", _) do
    {:ok, {200, %{"latest_stable_version" => "1.23"}, []}}
  end

  def get(nil, "not_existing", _) do
    {:ok, {404, %{}, []}}
  end
end
