package testimpl

import (
	"context"
	"crypto/tls"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/arm"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/cloud"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservice/armcontainerservice/v4"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"gopkg.in/yaml.v2"
	"k8s.io/kops/pkg/kubeconfig"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/nexient-llc/lcaf-component-terratest-common/types"
	"github.com/stretchr/testify/assert"
)

func GetManagedClusterClient(t *testing.T, testContext types.TestContext) *armcontainerservice.ManagedClustersClient {
	subscriptionID := os.Getenv("AZURE_SUBSCRIPTION_ID")
	if len(subscriptionID) == 0 {
		t.Fatal("AZURE_SUBSCRIPTION_ID is not set in the environment variables ")
	}
	credential, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		t.Fatalf("Unable to get credentials: %e\n", err)
	}
	options := arm.ClientOptions{
		ClientOptions: azcore.ClientOptions{
			Cloud: cloud.AzurePublic,
		},
	}
	clientFactory, err := armcontainerservice.NewClientFactory(subscriptionID, credential, &options)
	if err != nil {
		t.Fatalf("Unable to get clientFactory: %e\n", err)
	}
	return clientFactory.NewManagedClustersClient()
}

func TestComposableComplete(t *testing.T, testContext types.TestContext) {
	expectedClusterName := terraform.Output(t, testContext.TerratestTerraformOptions(), "cluster_name")
	expectedClusterId := terraform.Output(t, testContext.TerratestTerraformOptions(), "cluster_id")
	expectedRgName := terraform.Output(t, testContext.TerratestTerraformOptions(), "resource_group_name")
	expectedClusterHostName := terraform.Output(t, testContext.TerratestTerraformOptions(), "host")

	client := GetManagedClusterClient(t, testContext)
	ctx := context.Background()

	cluster, err := client.Get(ctx, expectedRgName, expectedClusterName, nil)
	if err != nil {
		t.Fatalf("Error occurred: %e\n", err)
	}
	fmt.Printf("ClusterId: %s\n", *cluster.ID)

	credentials, err := client.ListClusterAdminCredentials(ctx, expectedRgName, expectedClusterName, nil)
	if err != nil {
		t.Fatalf("Error occurred: %e\n", err)
	}
	kubeConfig := credentials.Kubeconfigs[0].Value

	kops := kubeconfig.KubectlConfig{}
	err = yaml.Unmarshal(kubeConfig, &kops)
	if err != nil {
		t.Fatalf("Unable to unmarshall: %e\n", err)
	}
	fmt.Printf("Server Name: %s\n", kops.Clusters[0].Cluster.Server)

	t.Run("TestClusterIsCreated", func(t *testing.T) {
		assert.NotEmpty(t, expectedClusterName, "Cluster Name must not be empty")
		assert.NotEmpty(t, expectedRgName, "Resource Group Name must not be empty")

	})

	t.Run("PrivateAPIServerURL", func(t *testing.T) {
		assert.Equal(t, expectedClusterHostName, kops.Clusters[0].Cluster.Server, "FQDN must match")
	})

	t.Run("ValidateClusterId", func(t *testing.T) {
		// The literal string ResourceGroup is not consistent in the ID strings. Hence, comparing the lower
		assert.Equal(t, strings.ToLower(expectedClusterId), strings.ToLower(*cluster.ID), "ID must match")
	})
}

func TestPrivateCluster(t *testing.T, testContext types.TestContext) {
	testContext.EnabledOnlyForTests(t, "private-cluster")
	expectedClusterName := terraform.Output(t, testContext.TerratestTerraformOptions(), "cluster_name")
	expectedClusterId := terraform.Output(t, testContext.TerratestTerraformOptions(), "cluster_id")
	expectedRgName := terraform.Output(t, testContext.TerratestTerraformOptions(), "resource_group_name")
	expectedClusterHostName := terraform.Output(t, testContext.TerratestTerraformOptions(), "host")

	client := GetManagedClusterClient(t, testContext)
	ctx := context.Background()

	cluster, err := client.Get(ctx, expectedRgName, expectedClusterName, nil)
	if err != nil {
		t.Fatalf("Error occurred: %e\n", err)
	}
	fmt.Printf("ClusterId: %s\n", *cluster.ID)

	credentials, err := client.ListClusterAdminCredentials(ctx, expectedRgName, expectedClusterName, nil)
	if err != nil {
		t.Fatalf("Error occurred: %e\n", err)
	}
	kubeConfig := credentials.Kubeconfigs[0].Value

	kops := kubeconfig.KubectlConfig{}
	err = yaml.Unmarshal(kubeConfig, &kops)
	if err != nil {
		t.Fatalf("Unable to unmarshall: %e\n", err)
	}
	fmt.Printf("Server Name: %s\n", kops.Clusters[0].Cluster.Server)

	t.Run("TestClusterIsCreated", func(t *testing.T) {
		assert.NotEmpty(t, expectedClusterName, "Cluster Name must not be empty")
		assert.NotEmpty(t, expectedRgName, "Resource Group Name must not be empty")

	})

	t.Run("PrivateAPIServerURL", func(t *testing.T) {
		assert.Equal(t, expectedClusterHostName, kops.Clusters[0].Cluster.Server, "FQDN must match")
	})

	t.Run("ValidateClusterId", func(t *testing.T) {
		// The literal string ResourceGroup is not consistent in the ID strings. Hence, comparing the lower
		assert.Equal(t, strings.ToLower(expectedClusterId), strings.ToLower(*cluster.ID), "ID must match")
	})
}

func TestPublicCluster(t *testing.T, testContext types.TestContext) {
	testContext.EnabledOnlyForTests(t, "public-cluster")
	kubeConfigRaw := terraform.Output(t, testContext.TerratestTerraformOptions(), "kube_config_raw")
	assert.NotEmpty(t, kubeConfigRaw, "kube_config_raw must not be empty")

	kubeConfigPath := "./kubeconfig"
	namespace := "demo"

	// Create kube config file
	err := createKubeConfig(kubeConfigRaw, kubeConfigPath)

	if err != nil {
		t.Fatalf("AKS KubeConfig test has failed: %e", err)
	}
	defer func(name string) {
		err := os.Remove(name)
		if err != nil {
			t.Fatalf("Unable to remove kubeconfig file: %e", err)
		}
	}(kubeConfigPath)

	kubectlOptions := k8s.NewKubectlOptions("", kubeConfigPath, namespace)
	defer k8s.DeleteNamespace(t, kubectlOptions, namespace)
	k8s.CreateNamespace(t, kubectlOptions, namespace)

	// Test the default node pool
	t.Run("TestDefaultNodePoolNodes", func(t *testing.T) {
		nodes := k8s.GetNodes(t, kubectlOptions)
		fmt.Println("Node Lists:")
		fmt.Println(len(nodes))
		defaultNodePoolNodes := 0
		for _, n := range nodes {
			if strings.Contains(n.Name, "aks-default") {
				defaultNodePoolNodes += 1
			}
			fmt.Println(n.Name)
		}
		assert.Equal(t, defaultNodePoolNodes, 2, "Number of node in default node pool should be 2")
	})

	t.Run("TestK8sService", func(t *testing.T) {
		k8sManifestPath := "../../resources/hello-world-app/app.yaml"

		/* Clean our cluster after this method execution */
		defer k8s.KubectlDelete(t, kubectlOptions, k8sManifestPath)

		/* Deploy our manifest files to cluster */
		k8s.KubectlApply(t, kubectlOptions, k8sManifestPath)

		expectedServiceName := "aks-helloworld"

		k8s.WaitUntilServiceAvailable(t, kubectlOptions, expectedServiceName, 10, 10*time.Second)
		deploy := k8s.GetDeployment(t, kubectlOptions, expectedServiceName)
		assert.Equal(t, expectedServiceName, deploy.Name, "The deployment name must match")
		service := k8s.GetService(t, kubectlOptions, expectedServiceName)
		serviceEndpoint := k8s.GetServiceEndpoint(t, kubectlOptions, service, 80)
		url := fmt.Sprintf("http://%s", serviceEndpoint)
		fmt.Printf("Service Endpoint: %s\n", url)
		tlsConfig := &tls.Config{}
		http_helper.HttpGetWithRetryWithCustomValidation(t, url, tlsConfig, 10, 10*time.Second, func(statusCode int, body string) bool {
			isOk := statusCode == 200
			isResponseBody := strings.Contains(body, "Hello World")

			return isOk && isResponseBody
		})
	})
}

func createKubeConfig(aksKubeConfig string, kubeConfigPath string) error {
	// get a bytes array with the AKS kube config
	kubeConfigBytes := []byte(aksKubeConfig)

	// write a temporary file with kube config
	err := os.WriteFile(kubeConfigPath, kubeConfigBytes, 0644)
	if err != nil {
		return err
	}

	return nil
}
