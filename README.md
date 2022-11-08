# Pod Security Admission (PSA) Testing for Kubernetes 1.23

## Testing Summary

Several test scenarios were executed against a Kubernetes 1.23 cluster, with [Pod Security Admission (PSA)](https://kubernetes.io/docs/concepts/security/pod-security-admission/) and [Pod Security Standards (PSS)](https://kubernetes.io/docs/concepts/security/pod-security-standards/) _Privileged_ profile enabled by default. The testing was designed to exercise different PSA modes and PSS profiles, while producing the following responses:

* Allowing Pods that meet profile requirements
* Disallowing pods that don’t meet profile requirements
* Allowing Deployments, even if Pods did not meet PSS profile requirements
* Failure (forbidden) responses to Kubernetes API server clients when Pods don’t meet profile requirements
* Deployment resource statuses, reflecting failed (forbidden) Pods
* Kubernetes API server logs with PSA controller responses, reflecting failed (forbidden) Pods
* Warning messages to Kubernetes API server clients when Deployments contained Pod specs that failed PSS profile requirements

## Testing Outcomes

* PSA functions correctly in Kubernetes 1.23
* PSS profiles (Privileged, Baseline, and Restricted) function as expected in Kubenetes 1.23
* PSA modes (audit, enforce, and warn) function as expected in Kubernetes 1.23

## Testing Assumptions

* PSA _Enforce_ mode only affects Pods, and does not affect workload resource controllers (Deployment, etc.) that create Pods.
* No PSA exemptions are configured at API server startup, for the PSA controller.
* The _Privileged_ PSS profile is configured by default for all PSA modes, and set to latest versions.

```
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1beta1
    kind: PodSecurityConfiguration
    # Defaults applied when a mode label is not set.
    #
    # Level label values must be one of:
    # - "privileged" (default)
    # - "baseline"
    # - "restricted"
    #
    # Version label values must be one of:
    # - "latest" (default) 
    # - specific version like "v1.24"
    defaults:
      enforce: "privileged"
      enforce-version: "latest"
      audit: "privileged"
      audit-version: "latest"
      warn: "privileged"
      warn-version: "latest"
    exemptions:
      # Array of authenticated usernames to exempt.
      usernames: []
      # Array of runtime class names to exempt.
      runtimeClasses: []
      # Array of namespaces to exempt.
      namespaces: []
```      

## Testing Setup and Execution

* policy-test Namespace created

```
apiVersion: v1
kind: Namespace
metadata:
  name: policy-test
  labels:    
    # pod-security.kubernetes.io/enforce: privileged
    # pod-security.kubernetes.io/audit: privileged
    # pod-security.kubernetes.io/warn: privileged
    
    # pod-security.kubernetes.io/enforce: baseline
    # pod-security.kubernetes.io/audit: baseline
    # pod-security.kubernetes.io/warn: baseline
    
    # pod-security.kubernetes.io/enforce: restricted
    # pod-security.kubernetes.io/audit: restricted
    # pod-security.kubernetes.io/warn: restricted
```

* Known good Kubernetes Deployment created and then deleted

```
apiVersion: apps/v1
kind: Deployment
namespace: policy-test
... 
    spec: 
      containers:
      - name: test
        image: public.ecr.aws/r2l1x4g2/go-http-server:v0.1.0-23ffe0a715
        imagePullPolicy: IfNotPresent
        securityContext:  
          allowPrivilegeEscalation: false  
          runAsUser: 1000  
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop: ["ALL"]  
          seccompProfile:
            type: "RuntimeDefault"
        ports:
        - containerPort: 8080
...        
```

* Known bad Kubernetes Deployment created
    * No securityContext element at the Pod level
    * No securityContext element at the Container level

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test
  namespace: policy-test
...
    spec: 
      containers:
      - name: test
        image: public.ecr.aws/r2l1x4g2/go-http-server:v0.1.0-23ffe0a715
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
...        
```

* Known bad Pod created
    * No securityContext element at the Pod level
    * No securityContext element at the Container level

```
apiVersion: v1
kind: Pod
metadata:
  name: test
  namespace: policy-test
...
spec:
  containers:
    - name: test
      image: public.ecr.aws/r2l1x4g2/go-http-server:v0.1.0-23ffe0a715
      imagePullPolicy: IfNotPresent
      ports:
      - containerPort: 8080
...
```

* Known bad Pod created
    * securityContext element at the Pod level exists with valid runAsUser and runAsNonRoot elements.
    * No securityContext element at the Container level

```
apiVersion: v1
kind: Pod
metadata:
  name: test2
  namespace: policy-test
...
spec:
  securityContext:  
    runAsUser: 1000  
    runAsNonRoot: true
  containers:
    - name: test
      image: public.ecr.aws/r2l1x4g2/go-http-server:v0.1.0-23ffe0a715
      imagePullPolicy: IfNotPresent
      ports:
      - containerPort: 8080
...
```

* Known bad Pod created
    * No securityContext element at the Pod level.
    * securityContext element at the Container level exists with incorrect settings for allowPrivilegeEscalation, readOnlyRootFilesystem, and runAsNonRoot

```
apiVersion: v1
kind: Pod
metadata:
  name: test3
  namespace: policy-test
...
spec:
  containers:
    - name: test
      image: public.ecr.aws/r2l1x4g2/go-http-server:v0.1.0-23ffe0a715
      imagePullPolicy: IfNotPresent
      securityContext:  
        allowPrivilegeEscalation: true  
        runAsUser: 1000  
        readOnlyRootFilesystem: false
        runAsNonRoot: false
        capabilities:
          drop: ["ALL"]  
        seccompProfile:
          type: "RuntimeDefault"
      ports:
...
```

* Known bad Pod created
    * No securityContext element at the Pod level.
    * securityContext element at the Container level exists with correct settings
    * Pod spec has incorrect hostNetwork, hostPID, and hostIPC settings

```
apiVersion: v1
kind: Pod
metadata:
  name: test4
  namespace: policy-test
...
spec:
  hostNetwork: true
  hostPID: true
  hostIPC: true
  containers:
    - name: test
      image: public.ecr.aws/r2l1x4g2/go-http-server:v0.1.0-23ffe0a715
      imagePullPolicy: IfNotPresent
      securityContext:  
        allowPrivilegeEscalation: false  
        runAsUser: 1000  
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        capabilities:
          drop: ["ALL"]  
        seccompProfile:
          type: "RuntimeDefault"
      ports:
      - containerPort: 8080
...
```

## Testing Scenarios

### PSA Modes Enabled with Default (Cluster Level) PSS Privileged Profile

* Namespace Config (no Namespace-level settings)

```
apiVersion: v1
kind: Namespace
metadata:
  name: policy-test
  labels:    
    # pod-security.kubernetes.io/enforce: privileged
    # pod-security.kubernetes.io/audit: privileged
    # pod-security.kubernetes.io/warn: privileged
    
    # pod-security.kubernetes.io/enforce: baseline
    # pod-security.kubernetes.io/audit: baseline
    # pod-security.kubernetes.io/warn: baseline
    
    # pod-security.kubernetes.io/enforce: restricted
    # pod-security.kubernetes.io/audit: restricted
    # pod-security.kubernetes.io/warn: restricted
```

* Test Output - Default PSS Privileged Profile Applied (5 Pods allowed, 0 Pods disallowed)

```
namespace/policy-test created


>>> 1. Good config...
deployment.apps/test created
deployment.apps "test" deleted


>>> 2. Deployment - Missing container security context element...
deployment.apps/test created


>>> 3. Pod - Missing container security context element...
pod/test created


>>> 4. Pod - Pod security context, but Missing container security context element...
pod/test2 created


>>> 5. Pod - Container security context element present, with incorrect settings...
pod/test3 created


>>> 6. Pod - Container security context element present, with incorrect spec.hostNetwork, spec.hostPID, spec.hostIPC settings...
pod/test4 created

k -n policy-test get po
NAME                   READY   STATUS    RESTARTS   AGE
test                   1/1     Running   0          70s
test-59955f994-djtqz   1/1     Running   0          76s
test2                  1/1     Running   0          65s
test3                  1/1     Running   0          59s
test4                  1/1     Running   0          55s
```

### All PSA Modes Enabled for Privileged PSS Profile (Namespace Level)

* Namespace Config

```
apiVersion: v1
kind: Namespace
metadata:
  name: policy-test
  labels:    
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
    
    # pod-security.kubernetes.io/enforce: baseline
    # pod-security.kubernetes.io/audit: baseline
    # pod-security.kubernetes.io/warn: baseline
    
    # pod-security.kubernetes.io/enforce: restricted
    # pod-security.kubernetes.io/audit: restricted
    # pod-security.kubernetes.io/warn: restricted
```

* Test Output - Namespace-level PSS Privileged Profile Applied (5 Pods allowed, 0 Pods disallowed)

```
namespace/policy-test created


>>> 1. Good config...
deployment.apps/test created
deployment.apps "test" deleted


>>> 2. Deployment - Missing container security context element...
deployment.apps/test created


>>> 3. Pod - Missing container security context element...
pod/test created


>>> 4. Pod - Pod security context, but Missing container security context element...
pod/test2 created


>>> 5. Pod - Container security context element present, with incorrect settings...
pod/test3 created


>>> 6. Pod - Container security context element present, with incorrect spec.hostNetwork, spec.hostPID, spec.hostIPC settings...
pod/test4 created

k -n policy-test get po
NAME                   READY   STATUS    RESTARTS   AGE
test                   1/1     Running   0          54s
test-59955f994-cssz9   1/1     Running   0          59s
test2                  1/1     Running   0          48s
test3                  1/1     Running   0          42s
test4                  1/1     Running   0          38s
```

### All PSA Modes Enabled for Baseline PSS Profile (Namespace Level)

* Namespace Config

```
apiVersion: v1
kind: Namespace
metadata:
  name: policy-test
  labels:    
    # pod-security.kubernetes.io/enforce: privileged
    # pod-security.kubernetes.io/audit: privileged
    # pod-security.kubernetes.io/warn: privileged
    
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
    
    # pod-security.kubernetes.io/enforce: restricted
    # pod-security.kubernetes.io/audit: restricted
    # pod-security.kubernetes.io/warn: restricted
```

* Test Output - Namespace-level PSS Baseline Profile Applied (4 Pods allowed, 1 Pod disallowed)

```
namespace/policy-test created


>>> 1. Good config...
deployment.apps/test created
deployment.apps "test" deleted


>>> 2. Deployment - Missing container security context element...
deployment.apps/test created


>>> 3. Pod - Missing container security context element...
pod/test created


>>> 4. Pod - Pod security context, but Missing container security context element...
pod/test2 created


>>> 5. Pod - Container security context element present, with incorrect settings...
pod/test3 created


>>> 6. Pod - Container security context element present, with incorrect spec.hostNetwork, spec.hostPID, spec.hostIPC settings...
Error from server (Forbidden): error when creating "policy/psa-pss/tests/6-pod.yaml": pods "test4" is forbidden: violates PodSecurity "baseline:latest": host namespaces (hostNetwork=true, hostPID=true, hostIPC=true), hostPort (container "test" uses hostPort 8080)

k -n policy-test get po
NAME                   READY   STATUS    RESTARTS   AGE
test                   1/1     Running   0          46s
test-59955f994-6tbj7   1/1     Running   0          52s
test2                  1/1     Running   0          42s
test3                  1/1     Running   0          37s
```

### All PSA Modes Enabled for Restricted PSS Profile (Namespace Level)

* Namespace Config

```
apiVersion: v1
kind: Namespace
metadata:
  name: policy-test
  labels:
    # pod-security.kubernetes.io/enforce: privileged
    # pod-security.kubernetes.io/audit: privileged
    # pod-security.kubernetes.io/warn: privileged
    
    # pod-security.kubernetes.io/enforce: baseline
    # pod-security.kubernetes.io/audit: baseline
    # pod-security.kubernetes.io/warn: baseline
    
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

* Test Output - Namespace-level PSS Restricted Profile Applied (0 Pods allowed, 5 Pods disallowed)
    * 1 Deployment created, with 0 Pods allowed

```
namespace/policy-test created


>>> 1. Good config...
deployment.apps/test created
deployment.apps "test" deleted


>>> 2. Deployment - Missing container security context element...
Warning: would violate PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "test" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "test" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "test" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "test" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
deployment.apps/test created


>>> 3. Pod - Missing container security context element...
Error from server (Forbidden): error when creating "policy/psa-pss/tests/3-pod.yaml": pods "test" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "test" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "test" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "test" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "test" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")


>>> 4. Pod - Pod security context, but Missing container security context element...
Error from server (Forbidden): error when creating "policy/psa-pss/tests/4-pod.yaml": pods "test2" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "test" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "test" must set securityContext.capabilities.drop=["ALL"]), seccompProfile (pod or container "test" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")


>>> 5. Pod - Container security context element present, with incorrect settings...
Error from server (Forbidden): error when creating "policy/psa-pss/tests/5-pod.yaml": pods "test3" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "test" must set securityContext.allowPrivilegeEscalation=false), runAsNonRoot != true (container "test" must not set securityContext.runAsNonRoot=false)


>>> 6. Pod - Container security context element present, with incorrect spec.hostNetwork, spec.hostPID, spec.hostIPC settings...
Error from server (Forbidden): error when creating "policy/psa-pss/tests/6-pod.yaml": pods "test4" is forbidden: violates PodSecurity "restricted:latest": host namespaces (hostNetwork=true, hostPID=true, hostIPC=true), hostPort (container "test" uses hostPort 8080)

k -n policy-test get po
No resources found in policy-test namespace.

k -n policy-test get deploy test -oyaml
...
status:
  conditions:
...
  - lastTransitionTime: "2022-07-12T23:56:10Z"
    lastUpdateTime: "2022-07-12T23:56:10Z"
    message: 'pods "test-59955f994-wl8hf" is forbidden: violates PodSecurity "restricted:latest":
      allowPrivilegeEscalation != false (container "test" must set securityContext.allowPrivilegeEscalation=false),
      unrestricted capabilities (container "test" must set securityContext.capabilities.drop=["ALL"]),
      runAsNonRoot != true (pod or container "test" must set securityContext.runAsNonRoot=true),
      seccompProfile (pod or container "test" must set securityContext.seccompProfile.type
      to "RuntimeDefault" or "Localhost")'
    reason: FailedCreate
    status: "True"
    type: ReplicaFailure
...
```

## Useful Commands
### Label Namespace
```
kubectl label --overwrite ns policy-test pod-security.kubernetes.io/enforce=restricted \
pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted
```
### Check Namespace Labels
```
kubectl get ns policy-test -L pod-security.kubernetes.io/enforce \
-L pod-security.kubernetes.io/warn -L pod-security.kubernetes.io/audit
```

## References
* https://aws.github.io/aws-eks-best-practices/security/docs/pods/#pod-security-standards-pss-and-pod-security-admission-psa
* https://kubernetes.io/docs/concepts/security/pod-security-standards/
* https://kubernetes.io/docs/concepts/security/pod-security-admission/

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

