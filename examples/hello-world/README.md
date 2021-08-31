# Example Workflow: Hello World

This is an example workflow that will simply run the hello-world image from Docker Hub on the worker.

First, make sure that the image is on the registry:

```
kubectl run skopeo -i --rm --restart=Never --image=none --overrides='{"spec":{"containers":[{"args":["copy","--dest-creds=$(REGISTRY_AUTH_USERNAME):$(REGISTRY_AUTH_PASSWORD)","--dest-tls-verify=false","docker://docker.io/hello-world:latest","docker://registry.default.svc.cluster.local/hello-world:latest"],"env":[{"name":"REGISTRY_AUTH_PASSWORD","valueFrom":{"secretKeyRef":{"name":"tinkerbell","key":"TINKERBELL_REGISTRY_PASSWORD"}}},{"name":"REGISTRY_AUTH_USERNAME","valueFrom":{"secretKeyRef":{"name":"tinkerbell","key":"TINKERBELL_REGISTRY_USERNAME"}}}],"image":"quay.io/containers/skopeo:v1.1.1","name":"skopeo"}]}}'
```

Then, push the hardware configuration, create the template and create the workflow:

```
kubectl exec -i $(kubectl get pod -l app=tink-cli -o name) -- tink hardware push < hardware-data.json
TEMPLATE_ID=`kubectl exec -i $(kubectl get pod -l app=tink-cli -o name) -- tink template create --name hello-world < hello-world.yml | awk -F: '{print $2}'`
kubectl exec -i $(kubectl get pod -l app=tink-cli -o name) -- tink workflow create -t ${TEMPLATE_ID} -r '{"device_1":"08:00:27:00:00:01"}'
```
