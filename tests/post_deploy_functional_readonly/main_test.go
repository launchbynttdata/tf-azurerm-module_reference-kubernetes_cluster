// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package test

import (
	"testing"

	"github.com/nexient-llc/lcaf-component-terratest-common/lib"
	"github.com/nexient-llc/lcaf-component-terratest-common/types"
	"github.com/nexient-llc/tf-azurerm-module_ref-kubernetes_cluster/tests/testimpl"
)

const (
	// Currently read-only tests are designed only to run on individual examples
	testConfigsExamplesFolderDefault = "../../examples/private-cluster"
	infraTFVarFileNameDefault        = "test.tfvars"
)

func TestKubernetesModule(t *testing.T) {
	ctx := types.CreateTestContextBuilder().
		SetTestConfig(&testimpl.ThisTFModuleConfig{}).
		SetTestConfigFolderName(testConfigsExamplesFolderDefault).
		SetTestConfigFileName(infraTFVarFileNameDefault).
		SetTestSpecificFlags(map[string]types.TestFlags{
			// The managed identity attached to AKS cluster causes non-idempotent apply
			"public-cluster": {
				"IS_TERRAFORM_IDEMPOTENT_APPLY": false,
			},
			"private-cluster": {
				"IS_TERRAFORM_IDEMPOTENT_APPLY": false,
			},
		}).
		Build()

	lib.RunNonDestructiveTest(t, *ctx, testimpl.TestComposableComplete)
}
