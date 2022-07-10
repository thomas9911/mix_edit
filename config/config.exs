import Config

if Mix.env() == :test do
  Application.put_env(:mix_edit, :version_fetcher, MixEdit.FakePackage)
end
