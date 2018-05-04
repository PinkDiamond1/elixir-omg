#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

defmodule OmiseGO.JSONRPC.Mixfile do
  use Mix.Project

  def project do
    [
      app: :omisego_jsonrpc,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      env: [
        # our own rpc port where OmiseGO.API is exposed
        omisego_api_rpc_port: 4000
      ],
      extra_applications: [:logger],
      mod: {OmiseGO.JSONRPC.Application, []}
    ]
  end

  defp deps do
    [
      {:jsonrpc2, "~> 1.0"},
      {:cowboy, "~> 1.1"},
      {:poison, "~> 3.1"},
      {:omisego_api, in_umbrella: true, runtime: false}
    ]
  end
end
