# Cilium

## OpnSense BGP

```sh
router bgp 64513
  bgp router-id 10.10.0.1
  no bgp ebgp-requires-policy

  neighbor k8s peer-group
  neighbor k8s remote-as 64514

  neighbor 10.10.0.21 peer-group k8s
  neighbor 10.10.0.22 peer-group k8s
  neighbor 10.10.0.23 peer-group k8s

  address-family ipv4 unicast
    neighbor k8s next-hop-self
    neighbor k8s soft-reconfiguration inbound
  exit-address-family
exit
```

## Mikrotik BGP (ROS 7.18.2)
```sh
/routing bgp connection
add add-path-out=none address-families=ip as=64513 connect=yes disabled=no \
    keepalive-time=3m listen=yes local.port=179 .role=ebgp name=K8S_NODE_1 \
    nexthop-choice=force-self output.default-originate=always remote.address=\
    10.10.0.21/32 .port=179
add add-path-out=none address-families=ip as=64513 connect=yes disabled=no \
    keepalive-time=3m listen=yes local.port=179 .role=ebgp name=K8S_NODE_2 \
    nexthop-choice=force-self output.default-originate=always remote.address=\
    10.10.0.22/32 .port=179
add add-path-out=none address-families=ip as=64513 connect=yes disabled=no \
    keepalive-time=3m listen=yes local.port=179 .role=ebgp name=K8S_NODE_3 \
    nexthop-choice=force-self output.default-originate=always remote.address=\
    10.10.0.23/32 .port=179
```
