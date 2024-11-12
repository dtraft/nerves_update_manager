defmodule NervesUpdateManager.VersionProvider do
  @doc """
  Given a `Version.Requirement`, fetch the latest version which
  matches the provided requirement.
  """
  @callback get_latest_matching_version(requirement :: Version.Requirement.t()) ::
              {:ok, Version.t()}
              | :no_matching_version
              | {:error, any()}
end
