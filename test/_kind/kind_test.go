package kind_test

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/tinkerbell/tink/client"
	"github.com/tinkerbell/tink/pkg"
	"github.com/tinkerbell/tink/protos/hardware"
	"github.com/tinkerbell/tink/protos/template"
	"github.com/tinkerbell/tink/protos/workflow"
)

func TestKindSetupGuide(t *testing.T) {
	ctx := context.Background()

	cmd := exec.CommandContext(ctx, "/bin/sh", "-c", "kind create cluster --config ../../deploy/kubevirt/kind-config.yaml")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	defer func() {
		cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kind delete cluster")
		out, err = cmd.CombinedOutput()
		if err != nil {
			t.Logf("%s", out)
			t.Fatal(err)
		}
	}()

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl wait node --all --for condition=ready --timeout 300s")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "docker exec -i kind-control-plane sh -c 'echo 0 >/proc/sys/net/bridge/bridge-nf-call-iptables'")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "docker exec -i kind-control-plane sh -c 'curl -L https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz | tar -xzC /opt/cni/bin/ ./bridge ./portmap ./static'")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "curl https://raw.githubusercontent.com/intel/multus-cni/master/images/multus-daemonset.yml | sed 's|:stable|:latest|' | kubectl apply -f-")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl wait pod -l app=multus -n kube-system --for condition=ready --timeout 300s")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl apply -f ../../deploy/kubevirt/multus-networks.yaml")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v0.34.2/kubevirt-operator.yaml")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl wait deploy --all -n kubevirt --for condition=available --timeout 300s")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v0.34.2/kubevirt-cr.yaml")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "./generate-envrc.sh ${TINKERBELL_NETWORK_INTERFACE} >./deploy/kubernetes/envrc.yaml")
	cmd.Dir = "../.."
	cmd.Env = append(os.Environ(),
		"TINKERBELL_NETWORK_INTERFACE=docker0",
		"TINKERBELL_HOST_IP=192.168.1.1",
		"TINKERBELL_NGINX_IP=192.168.1.2",
		"TINKERBELL_NGINX_URL=http://192.168.1.2",
		"TINKERBELL_REGISTRY_IP=192.168.1.3",
		"TINKERBELL_TINK_IP=192.168.1.4",
	)
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "./setup.sh")
	cmd.Dir = "../.."
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}
	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl apply -f ../../deploy/kubernetes")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl wait deploy -l app!=dhcrelay --for condition=available --timeout 300s")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl wait job --all --for condition=complete --timeout 1h")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl run skopeo -i --rm --restart=Never --image=none --overrides='{\"spec\":{\"containers\":[{\"args\":[\"copy\",\"--dest-creds=$(REGISTRY_USERNAME):$(REGISTRY_PASSWORD)\",\"--dest-tls-verify=false\",\"docker://docker.io/hello-world:latest\",\"docker://$(REGISTRY_HOST)/hello-world:latest\"],\"envFrom\":[{\"secretRef\":{\"name\":\"registry\"}}],\"image\":\"quay.io/containers/skopeo:v1.1.1\",\"name\":\"skopeo\"}]}}'")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	for ii := 0; ii < 5; ii++ {
		resp, err := http.Get("http://localhost:42114/healthz")

		if err != nil || resp.StatusCode != http.StatusOK {
			if err != nil {
				t.Logf("err tinkerbell healthcheck... retrying: %s", err)
			} else {
				t.Logf("err tinkerbell healthcheck... expected status code 200 got %d retrying", resp.StatusCode)
			}
			time.Sleep(10 * time.Second)
		}

		resp.Body.Close()
	}

	t.Log("Tinkerbell is up and running")

	os.Setenv("TINKERBELL_CERT_URL", "http://127.0.0.1:42114/cert")
	os.Setenv("TINKERBELL_GRPC_AUTHORITY", "127.0.0.1:42113")
	client.Setup()
	_, err = client.HardwareClient.All(ctx, &hardware.Empty{})
	if err != nil {
		t.Fatal(err)
	}
	err = registerHardware()
	if err != nil {
		t.Fatal(err)
	}

	templateID, err := registerTemplate(ctx)
	if err != nil {
		t.Fatal(err)
	}

	t.Logf("templateID: %s", templateID)

	workflowID, err := createWorkflow(ctx, templateID)
	if err != nil {
		t.Fatal(err)
	}

	t.Logf("WorkflowID: %s", workflowID)

	cmd = exec.CommandContext(ctx, "/bin/sh", "-c", "kubectl apply -f ../../deploy/kubevirt/worker.yaml")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", out)
		t.Fatal(err)
	}

	for iii := 0; iii < 30; iii++ {
		events, err := client.WorkflowClient.ShowWorkflowEvents(ctx, &workflow.GetRequest{
			Id: workflowID,
		})
		if err != nil {
			t.Fatal(err)
		}
		for event, err := events.Recv(); err == nil && event != nil; event, err = events.Recv() {
			if event.ActionName == "hello_world" && event.ActionStatus == workflow.State_STATE_SUCCESS {
				t.Logf("event %s SUCCEEDED as expected", event.ActionName)
				return
			}
		}
		time.Sleep(20 * time.Second)
	}
	t.Fatal("Workflow never got to a complite state or it didn't make it on time (20m)")
}

func createWorkflow(ctx context.Context, templateID string) (string, error) {
	res, err := client.WorkflowClient.CreateWorkflow(ctx, &workflow.CreateRequest{
		Template: templateID,
		Hardware: `{"device_1":"08:00:27:00:00:01"}`,
	})
	if err != nil {
		return "", err
	}
	return res.Id, nil
}

func registerTemplate(ctx context.Context) (string, error) {
	resp, err := client.TemplateClient.CreateTemplate(ctx, &template.WorkflowTemplate{
		Name: "hello-world",
		Data: `version: "0.1"
name: hello_world_workflow
global_timeout: 600
tasks:
  - name: "hello world"
    worker: "{{.device_1}}"
    actions:
      - name: "hello_world"
        image: hello-world
        timeout: 60`,
	})
	if err != nil {
		return "", err
	}

	return resp.Id, nil
}

func registerHardware() error {
	data := []byte(`{
  "id": "ce2e62ed-826f-4485-a39f-a82bb74338e2",
  "metadata": {
    "facility": {
      "facility_code": "onprem"
    },
    "instance": {},
    "state": ""
  },
  "network": {
    "interfaces": [
      {
        "dhcp": {
          "arch": "x86_64",
          "ip": {
            "address": "192.168.1.5",
            "gateway": "192.168.1.1",
            "netmask": "255.255.255.248"
          },
          "mac": "08:00:27:00:00:01",
          "uefi": false
        },
        "netboot": {
          "allow_pxe": true,
          "allow_workflow": true
        }
      }
    ]
  }
}`)
	hw := pkg.HardwareWrapper{Hardware: &hardware.Hardware{}}
	err := json.Unmarshal(data, &hw)
	if err != nil {
		return err
	}
	_, err = client.HardwareClient.Push(context.Background(), &hardware.PushRequest{Data: hw.Hardware})
	return err
}
