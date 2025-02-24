# Copyright 2019 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.ChildChainRPC.Web.TestHelper do
  @moduledoc """
  Provides common testing functions used by App's tests.
  """

  import ExUnit.Assertions
  use Plug.Test

  def rpc_call(method, path, params_or_body \\ nil) do
    request =
      conn(method, path, params_or_body)
      |> put_req_header("content-type", "application/json")

    response = send_request(request)

    assert response.status == 200
    # CORS check
    assert ["*"] == get_resp_header(response, "access-control-allow-origin")

    required_headers = [
      "access-control-allow-origin",
      "access-control-expose-headers",
      "access-control-allow-credentials"
    ]

    for header <- required_headers do
      assert header in Keyword.keys(response.resp_headers)
    end

    # CORS check
    Jason.decode!(response.resp_body)
  end

  defp send_request(req), do: OMG.ChildChainRPC.Web.Endpoint.call(req, [])
end
